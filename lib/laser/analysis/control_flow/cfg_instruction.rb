require 'set'
module Laser
  module SexpAnalysis
    module ControlFlow
      class Instruction < BasicObject
        attr_reader :node
        def initialize(body, opts={})
          @body = body
          @node = opts[:node]
        end

        def class
          Instruction
        end

        # Gets all bindings that are explicitly set in this instruction (no aliasing
        # concerns)
        def explicit_targets
          case self[0]
          when :assign, :call, :call_vararg, :super, :super_vararg, :lambda, :phi
            self[1] ? ::Set[self[1]] : ::Set[]
          else
            ::Set[]
          end
        end
  
        # Gets all bindings that are operands in this instruction
        def operands
          ::Set.new(self[operand_range].select { |x| Bindings::GenericBinding === x})
        end
        
        # Replaces the operands with a new list. Used by SSA renaming.
        def replace_operands(new_operands)
          self[operand_range] = new_operands
        end

        # Replaces a target of the instruction. Used by SSA renaming.
        # Currently, all instructions only have at most 1 target.
        def replace_target(original_target, new_target)
          if self[1] == original_target
            self[1] = new_target
          else
            raise ArgumentError.new("#{original_target.inspect} is not a "+
                                    "target of #{self.inspect}")
          end
        end

        def method_missing(meth, *args, &blk)
          @body.send(meth, *args, &blk)
        end

       private

        def operand_range
          case self[0]
          when :assign, :call, :call_vararg, :super, :super_vararg, :lambda, :phi
            2..-1
          else 1..-1
          end
        end
      end
    end
  end
end