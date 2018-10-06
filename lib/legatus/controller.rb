module Legatus
  module Controller
    extend ActiveSupport::Concern

    class_methods do
      attr_reader :services

      def service(services)
        @services = services.with_indifferent_access.freeze
      end
    end

    def execute
      executor = self.class.services[params[:action]].new(params)
      
      if executor.execute
        result = executor.as_json(except: ['params', 'props'])
        status = request.post? ? :created : :ok

        render json: result, status: status
      else
        render json: executor.errors
      end
    end

    def method_for_action(aname)
      return :execute if self.class.services.include?(aname)
      return super(aname)
    end
  end
end