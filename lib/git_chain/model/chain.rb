module GitChain
  class Model
    class Chain < Model
      attr_accessor :name, :branches

      def initialize(name:, branches: [])
        @name = name
        @branches = branches
      end

      def branch_names
        branches.map(&:name)
      end

      def empty?
        branches.empty?
      end

      class << self
        def from_config(name)
          chains = Git.chains(chain_name: name)
          branches = chains.keys.map(&Branch.method(:from_config))

          new(
            name: name,
            branches: sort_branches(branches),
          )
        end

        def sort_branches(branches)
          sorted = []
          remaining = branches.clone

          current_parent = nil
          until remaining.empty?
            node = remaining.find { |branch| branch.parent_branch == current_parent }
            raise(AbortError, "Branch #{current_parent} is not connected to the rest of the chain") unless node

            sorted << node
            remaining.delete(node)
            current_parent = node.name
          end

          sorted
        end
      end
    end
  end
end
