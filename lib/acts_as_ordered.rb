module ActiveRecord
  module Acts
    module Ordered
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_ordered(options = {})
          options.assert_valid_keys :order, :wrap, :condition, :scope
          
          options[:order]     = options[:order] ? "#{options[:order]}, #{primary_key}" : primary_key
          options[:condition] = options[:condition].to_proc if options[:condition].is_a?(Symbol)
          options[:scope]     = "#{options[:scope]}_id".to_sym if options[:scope].is_a?(Symbol) && options[:scope].to_s !~ /_id$/
          options[:scope]   ||= '1 = 1'
          
          scope_condition_method = if options[:scope].is_a?(Symbol)
           %(
            def ordered_scope_condition
              if #{options[:scope].to_s}.nil?
                "#{options[:scope].to_s} IS NULL"
              else
                "#{options[:scope].to_s} = \#{#{options[:scope].to_s}}"
              end
            end
           )
          else
            "def ordered_scope_condition() \"#{options[:scope]}\" end"
          end
          
          class_eval <<-END
            #{scope_condition_method}
            
            def adjacent_id(number)
              ids = ordered_ids
              ids.reverse! if number < 0
              index = ids.index(self.id)
              #{options[:wrap] ? 'ids[(index + number.abs) % ids.size]' : 'ids[index + number.abs] || ids.last'}
            end
            
            def ordered_ids
              conditions = []
              conditions << self.class.send(:type_condition) unless self.class.descends_from_active_record?
              conditions << ordered_scope_condition
              connection.select_values("SELECT #{primary_key} FROM #{table_name} WHERE (\#{conditions.join(') AND (')}) ORDER BY #{options[:order]}").map(&:to_i)
            end
          END
          
          cattr_accessor :_adjacent_condition
          self._adjacent_condition = options[:condition]
          
          include InstanceMethods
        end
      end
      
      module InstanceMethods
        def adjacent_record(options = {})
          previous_record, number = self, options.delete(:number)
          loop do
            adjacent_record = self.class.base_class.find(previous_record.adjacent_id(number), options.dup)
            matches = self.class._adjacent_condition ? self.class._adjacent_condition.call(adjacent_record) : true
            
            return adjacent_record if matches
            return self if adjacent_record == self # If the search for a matching record failed
            return self if previous_record == adjacent_record # If we've found the same adjacent_record twice
            
            previous_record = adjacent_record
            number = number < 0 ? -1 : 1
          end
        end
        
        def current_total
          self.class.base_class.count :conditions => ordered_scope_condition
        end
        
        def current_index
          ordered_ids.index(id)
        end
        
        def current_position
          current_index + 1
        end
        
        def next(options = {})
          options = options.reverse_merge(:number => 1)
          adjacent_record(options)
        end
        
        def previous(options = {})
          options = options.reverse_merge(:number => 1)
          options[:number] = -options[:number]
          adjacent_record(options)
        end
        
        def find_by_direction(direction, options = {})
          direction = direction.to_s
          ['next', 'previous'].include?(direction) ? send(direction, options) : raise("valid directions are next and previous")
        end
        
        def first_id
          ordered_ids.first
        end
        
        def last_id
          ordered_ids.last
        end
        
        def first
          self.class.base_class.find(first_id)
        end
        
        def last
          self.class.base_class.find(last_id)
        end
        
        def first?
          id == first_id
        end
        
        def last?
          id == last_id
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Ordered)
