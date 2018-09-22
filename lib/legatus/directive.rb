require 'flexcon'


module Legatus
  class Directive
    extend ActiveModel::Naming

    class << self
      attr_reader :properties, 
                  :models, 
                  :validations,
                  :transactions,
                  :callbacks
      
      def props
        schema = yield

        @properties = {}
        schema.each do |key, invocations|
          @properties[key] = Chain.new(invocations)
        end
      end

      def permit(parent, attributes, subschema=nil)
        result = parent.permit(attributes)
        result.tap do |whitelisted|
          subschema.each do |key, allowed|
            child = parent[key]
            next if child.nil?
            
            if child.is_a?(Array)
              whitelisted[:"#{key}_attributes"] = child.map { |c| c.permit(allowed) }
            else
              whitelisted[:"#{key}_attributes"] = child.permit(allowed)
            end
          end
        end
      end

      def model(mname, &block)
        @models ||= {}
        @models[mname] = block
      end

      def validate(*models)
        @validations ||= []
        @validations.concat(models)
      end

      def transaction(&block)
        @transactions ||= []
        @transactions << block
      end

      def callback
        @callbacks ||= {}
        @callbacks.merge!(yield)
      end
    end

    attr_reader :props, :params, :errors

    def initialize(params)
      @params = params
      @errors = {}
      @props = {}

      self.class.properties.each do |pname, chain|
        @props[pname] = chain.apply(params)
      end
    end

    def valid?
      return @errors.empty?
    end

    def invalid?
      return !@errors.empty?
    end

    def extract(*props)
      props.map { |prop| self.send(prop) }
    end

    def clean
      self.reqs(self.props, self.props.keys)
    end

    def load
      self.valid? and self.class.models.each do |mname, loader|
        self.send(:"#{mname}=", Flexcon.dispatch(self, loader))
      end
    end

    def validate
      self.valid? and self.class.validations.each do |mname|
        self.check(mname => self.send(mname))
      end if self.class.validations.present?

      self.valid? and self.class.models.each do |mname, loader|
        self.check(mname => self.send(mname))
      end if self.class.models.present?
    end

    def persist
      self.valid? and UnitOfWork.transaction do |uow|
        self.class.transactions.each do |handler|
          handler.call(uow, self)
        end
      end
    end
    
    def execute
      return (
        self.valid? and
        self.executed?(:clean) and
        self.executed?(:load) and 
        self.executed?(:validate) and
        self.executed?(:persist)
      )
    end

    protected
      def chain(obj, invocations)
        return Chain.new(invocations).apply(obj)
      end

      def reqs(source, attributes)
        attributes.each do |attribute|
          next if not source[attribute].blank?
          @errors[attribute] ||= {}
          @errors[attribute][:base] = []
          @errors[attribute][:base] << 'is required'
        end
      end

      def executed?(stepname)
        return (
          self.callback?(stepname, :before) and
          self.send(stepname) and
          self.callback?(stepname, :after)
        )
      end

      def callback?(mname, stage)
        return true if self.class.callbacks.blank?
        return true if self.class.callbacks[mname].blank?

        Flexcon.dispatch(self, self.class.callbacks[mname][stage])
      end

      def check(schema)
        schema.each do |key, model|
          if model.respond_to?(:each_with_index)
            self.check_many(key, model)
          else
            self.check_one(key, model)
          end
        end
      end

      def check_one(key, model)
        if model.invalid?
          @errors[key] ||= {}
          @errors[key].merge!(model.errors)
        end
      end

      def check_many(key, models)
        models.each_with_index do |m, i|
          if m.invalid?
            @errors[key] ||= {}
            @errors[key][i] ||= {}
            @errors[key][i].merge!(m.errors)
          end
        end
      end
  end
end