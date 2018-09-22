module Legatus
  class UnitOfWork

    def self.transaction
      ActiveRecord::Base.connection.transaction do 
        yield(UnitOfWork.new)
      end
    end

    def save(*models)
      models.all? { |model| model.save }
    end

    def update(*models)
      models.all? { |model| model.update }
    end

    def create(*models)
      models.all? { |model| model.create }
    end

    def destroy(*models)
      models.all? { |model| model.destroy }
    end

    def persist(*models)
      models.all? do |model| 
        if model.marked_for_destruction?
          model.destroy
        else
          model.save
        end
      end
    end
  end
end