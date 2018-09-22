module Legatus
  class Chain
    attr_reader :invocations

    def initialize(invocations)
      @invocations = invocations
    end

    def apply(source)
      result = source
      @invocations.each do |name, params|
        break if result.nil?
        
        if params.is_a?(Proc)
          result = result.send(name, &params)
        else
          result = result.send(name, *params)
        end
      end

      return result
    end
  end
end