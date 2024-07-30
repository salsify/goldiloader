# frozen_string_literal: true

module Goldiloader
  module Compatibility
    def self.pre_rails_7?
      ::ActiveRecord::VERSION::MAJOR < 7
    end

    def self.rails_6_1?
      ::ActiveRecord::VERSION::MAJOR == 6 && ::ActiveRecord::VERSION::MINOR == 1
    end

    def self.rails_6_1_or_greater?
      ::ActiveRecord::VERSION::MAJOR > 6 || rails_6_1?
    end

    def self.pre_rails_7_2?
      ::ActiveRecord::VERSION::MAJOR < 7 ||
        (::ActiveRecord::VERSION::MAJOR == 7 && ::ActiveRecord::VERSION::MINOR < 2)
    end
  end
end
