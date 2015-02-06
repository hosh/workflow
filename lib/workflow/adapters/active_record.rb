require 'active_support/concern'

module Workflow
  module Adapters
    module ActiveRecord
      extend ActiveSupport::Concern

      included do
        before_validation :write_initial_state # set initial state

        def load_workflow_state
          read_attribute(self.class.workflow_column)
        end

        # On transition the new workflow state is immediately saved in the
        # database.
        def persist_workflow_state(new_value)
          # Rails 3.1 or newer
          update_column self.class.workflow_column, new_value
        end

        # This section will automatically generate ActiveRecord scopes based on workflow states.
        # The name of each generated scope will be something like `with_<state_name>_state`
        #
        # Examples:
        #
        # Article.with_pending_state # => ActiveRecord::Relation
        # Payment.without_refunded_state # => ActiveRecord::Relation
        #`
        # Example above just adds `where(:state_column_name => 'pending')` or
        # `where.not(:state_column_name => 'pending')` to AR query and returns
        # ActiveRecord::Relation.
        def self.workflow_with_scopes(&specification)
          workflow_without_scopes(&specification)

          states = workflow_spec.states.values

          states.each do |state|
            define_singleton_method("with_#{state}_state") do
              where("#{table_name}.#{self.workflow_column.to_sym} = ?", state.to_s)
            end

            define_singleton_method("without_#{state}_state") do
              where.not("#{table_name}.#{self.workflow_column.to_sym} = ?", state.to_s)
            end
          end
        end

        def self.workflow(&specification)
          self.workflow_with_scopes(&specification)
        end

        private

        # Motivation: even if NULL is stored in the workflow_state database column,
        # the current_state is correctly recognized in the Ruby code. The problem
        # arises when you want to SELECT records filtering by the value of initial
        # state. That's why it is important to save the string with the name of the
        # initial state in all the new records.
        def write_initial_state
          write_attribute self.class.workflow_column, current_state.to_s
        end

      end
    end
  end
end
