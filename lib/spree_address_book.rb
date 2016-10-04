require 'spree_core'

module Spree
  module AddressBook
    class Engine < Rails::Engine
      engine_name 'spree_address_book'
      
      initializer "spree.advanced_cart.environment", :before => :load_config_initializers do |app|
        Spree::AddressBook::Config = Spree::AddressBookConfiguration.new
      end
      
      config.autoload_paths += %W(#{config.root}/lib)

      def self.activate
        Dir.glob(File.join(File.dirname(__FILE__), "../app/**/spree/*_decorator*.rb")) do |c|
          Rails.application.config.cache_classes ? require(c) : load(c)
        end
        Spree::Ability.register_ability(Spree::AddressAbility)
      end

      config.to_prepare &method(:activate).to_proc
    end
  end
end

module Spree
  module AddressBook
    class GoogleMaps
      include HTTParty
      base_uri 'https://maps.googleapis.com/maps/api'

      def initialize(language)
        @options = { query: { language: language, key: ENV['GOOGLE_SERVER_KEY'] }, 
                     timeout: 5 
                   }
      end

      def placedetails(placeid)
        @options = @options.deep_merge( { query: { placeid: placeid } } )
        begin
          response = self.class.get("/place/details/json", @options)
        rescue StandardError => e
          # rescue instances of StandardError, i.e. Timeout::Error, SocketError etc
          return false, e, 0.0, 0.0
        else
          if ( response.parsed_response["status"] == "OK" )
            formatted_address = response.parsed_response["result"]["formatted_address"]
            name = response.parsed_response["result"]["name"]
            lat = response.parsed_response["result"]["geometry"]["location"]["lat"]
            lng = response.parsed_response["result"]["geometry"]["location"]["lng"]
            address = ( (formatted_address.include? name) ? formatted_address : (name+" "+formatted_address) )
            return true, address.truncate(255), lat, lng # saved as string type so need to limit chars
          else
            return false, response.parsed_response["error_message"], 0.0, 0.0
          end
        end
      end

    end
  end
end
