module ActiveRecord
  module Acts
    module Ordered
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      class InvalidDirection < Exception
      end
      
      module ClassMethods
        def acts_as_ordered(options = {})
          options.assert_valid_keys :order, :scope
          
          options[:order] ||=  primary_key.to_sym
          options[:scope] ||= options[:scope]
          
          cattr_accessor :_acts_as_ordered_options
          self._acts_as_ordered_options = options
          
          include InstanceMethods
        end
      end
      
      module InstanceMethods
        def ordered_scope_conditions(cmp)
          condition_string = _acts_as_ordered_options[:scope].respond_to?(:call) ? _acts_as_ordered_options[:scope].call(self) : _acts_as_ordered_options[:scope]
          order = _acts_as_ordered_options[:order].respond_to?(:call) ? _acts_as_ordered_options[:order].call(self) : _acts_as_ordered_options[:order]
          if order.class.name == "Symbol"
            order = [order]
          end
          order = order.map{|k| self.send(k) ? k : nil}.compact

          ["#{condition_string} #{! condition_string || condition_string.empty? ? '' : 'AND'} (#{order.join(', ')}) #{cmp == :prev ? '<' : '>'} (#{Array.new(order.size,'?').join(', ')})"] + order.map{|k| self.send(k)}
          
        end
        
        def ordered_scope_order(cmp)
          condition_string = _acts_as_ordered_options[:scope].respond_to?(:call) ? _acts_as_ordered_options[:scope].call(self) : _acts_as_ordered_options[:scope]
          order = _acts_as_ordered_options[:order].respond_to?(:call) ? _acts_as_ordered_options[:order].call(self) : _acts_as_ordered_options[:order]
          if order.class.name == "Symbol"
            order = [order]
          end
          "#{order.map{|k| k.to_s + (cmp == :prev ? ' DESC' : ' ASC')}.join(',')}"       
        end
        
        def next
          conditions, options = [], self.class._acts_as_ordered_options
          if !options[:ignore_sti] && !self.class.descends_from_active_record?
            conditions << self.class.send(:type_condition)
          end
          self.class.where(ordered_scope_conditions(:next)).order(ordered_scope_order(:next)).first || self
          #self.class.find(:first, :conditions => ordered_scope_conditions(:next), :order => ordered_scope_order(:next)) || self
        end

        def previous
          conditions, options = [], self.class._acts_as_ordered_options
          if !options[:ignore_sti] && !self.class.descends_from_active_record?
            conditions << self.class.send(:type_condition)
          end
          self.class.where(ordered_scope_conditions(:prev)).order(ordered_scope_order(:prev)).first || self          
          #self.class.find(:first, :conditions => ordered_scope_conditions(:prev), :order => ordered_scope_order(:prev)) || self
        end
        
        def first
          self.class.where(_acts_as_ordered_options[:scope].respond_to?(:call) ? _acts_as_ordered_options[:scope].call(self) : _acts_as_ordered_options[:scope]).order(ordered_scope_order(:next)).first
          #self.class.first(:conditions => _acts_as_ordered_options[:scope].respond_to?(:call) ? _acts_as_ordered_options[:scope].call(self) : _acts_as_ordered_options[:scope], :order => ordered_scope_order(:next) )
        end
        
        def last
          self.class.where(_acts_as_ordered_options[:scope].respond_to?(:call) ? _acts_as_ordered_options[:scope].call(self) : _acts_as_ordered_options[:scope]).order(ordered_scope_order(:next)).last
          #self.class.last(:conditions => _acts_as_ordered_options[:scope].respond_to?(:call) ? _acts_as_ordered_options[:scope].call(self) : _acts_as_ordered_options[:scope], :order => ordered_scope_order(:next)  )
        end
      end
    end
  end
end
 
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Ordered)
