module Legatus
  module Repository
    extend ActiveSupport::Concern

    class_methods do
      def find_and_init(filters, attributes=nil)
        instance = self.find_one(filters)
        instance ||= self.new

        attributes ||= filters
        instance.assign_attributes(attributes) 

        return instance
      end

      def find_or_init(filters, attributes)
        instance = self.find_one(filters)
        return instance if instance.present?

        instance = self.new
        instance.assign_attributes(attributes) 
      end

      def find_one(filters)
        instance = filters.find { |f| self.find_by(f) } if filters.is_a?(Array)
        instance ||= self.find_by(filters)
        return instance
      end
    end
  end
end