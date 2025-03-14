# frozen_string_literal: true
require "optparse"

module GitChain
  module Commands
    class Rebase < Command
      include Options::ChainName

      def description
        "Rebase all branches of the chain"
      end

      def run(options)
        if Git.rebase_in_progress?
          raise(Abort, "A rebase is in progress. Please finish the rebase first and run 'git chain rebase' after.")
        end

        chain = current_chain(options)
        puts_debug("Rebasing chain #{chain.formatted}}}")

        if Git.cherry_pick_in_progress?
          cherry_pick_hash = Git.cherry_pick_hash()
          args = ["cherry-pick", "--continue"]
          puts_debug_git(*args)
          Git.exec_no_interactive(*args)
          puts "cherry pick hash #{cherry_pick_hash}!"
          chain.branches[1..-1].each do |branch|
            branch_sha = Git.rev_parse(branch.name)
            puts "branch hash #{branch_sha}!"
            if branch_sha == cherry_pick_hash
              args = ["checkout", "-B", branch.name]
              puts_debug_git(*args)
              Git.exec(*args)
            end
          end
#          rescue GitChain::Git::Failure => e
#            puts_warning(e.message)
#            raise(AbortSilent)
        end

        branches_to_rebase = chain.branches[1..-1]

        raise(Abort, "No branches to rebase for chain '#{chain.name}'.") if branches_to_rebase.empty?

        updates = 0

        branches_to_rebase.each do |branch|
          parent_sha = Git.rev_parse(branch.parent_branch)
          if parent_sha == branch.branch_point
            puts_debug("Branch {{info:#{branch.name}}} is already up-to-date.")
            next
          end

          updates += 1

          if parent_sha != branch.branch_point && forwardable_branch_point?(branch)
            puts_info("Auto-forwarding #{branch.name} to #{branch.parent_branch}")
            Git.set_config("branch.#{branch.name}.branchPoint", parent_sha)
            branch.branch_point = parent_sha
          end

          args = ["rebase", "--keep-empty", "--onto", branch.parent_branch, branch.branch_point, branch.name]
          puts_debug_git(*args)
          Git.exec(*args)
          Git.set_config("branch.#{branch.name}.branchPoint", parent_sha, scope: :local)
          # validate the parameters
        rescue GitChain::Git::Failure => e
          puts_warning(e.message)

          puts_error("Cannot merge #{branch.name} onto #{branch.parent_branch}.")
          puts_error("Fix the rebase and run {{command:git chain rebase}} again.")
          raise(AbortSilent)
        end

        if updates.positive?
          puts_success("Chain {{info:#{chain.name}}} successfully rebased.")
        else
          puts_info("Chain {{info:#{chain.name}}} is already up-to-date.")
        end
      end

      private

      def forwardable_branch_point?(branch)
        Git.ancestor?(ancestor: branch.parent_branch, rev: branch.name) ||
          Git.merge_base(branch.branch_point, Git.merge_base(branch.parent_branch, branch.name)) == branch.branch_point
      end
    end
  end
end
