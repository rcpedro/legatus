module Legatus
  class UnitOfWork

    def initialize
      @steps = []
    end

    def save(*models)
      @steps << lambda do 
        models.all? { |model| self.execute(:save, model) }
      end
    end

    def update(*models)
      @steps << lambda do 
        models.all? { |model| self.execute(:update, model) }
      end
    end

    def create(*models)
      @steps << lambda do 
        models.all? { |model| self.execute(:create, model) }
      end
    end

    def destroy(*models)
      @steps << lambda do 
        models.all? { |model| self.execute(:destroy, model) }
      end
    end

    def persist(*models)
      @steps << lambda do 
        models.all? do |model| 
          if model.is_a?(Array)
            model.all? { |elem| self.save_or_destroy(elem) }
          else
            self.save_or_destroy(model)
          end
        end
      end
    end

    def denormalize(model, schema)
      @steps << lambda do 
        schema.each do |field, subschema|
          assoc    = subschema.keys[0]
          aggre    = subschema.values[0].keys[0]
          subfield = subschema.values[0].values[0]

          model[field] = model.send(subschema.keys[0]).send(aggre, subfield)
        end
        model.save
      end
    end

    def commit
      ActiveRecord::Base.connection.transaction do 
        @steps.all? { |step| step.call }
      end
    end

    protected
      def execute(methodname, model)
        return model.all? { |elem| elem.send(methodname) } if model.is_a?(Array)
        return model.send(methodname)
      end

      def save_or_destroy(model)
        return model.destroy if model.marked_for_destruction?
        return model.save
      end
  end
end