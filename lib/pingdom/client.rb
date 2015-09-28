require File.join(File.dirname(__FILE__), '..', 'pingdom-ruby') unless defined? Pingdom

module Pingdom
  class Client

    attr_accessor :limit

    def initialize(options = {})
      @options = options.with_indifferent_access.reverse_merge(:http_driver => Faraday.default_adapter)

      raise ArgumentError, "an application key must be provided (as :key)" unless @options.key?(:key)

      @connection = Faraday::Connection.new(:url => "https://api/pingdom.com/api/2.0/", ssl: {verify: false}) do |builder|
        builder.url_prefix = "https://api.pingdom.com/api/2.0"
        builder.request  :url_encoded

        builder.adapter @options[:http_driver]

        builder.response :json, content_type: /\bjson$/
        builder.response :logger, @options[:logger] if @options[:logger]
        builder.use Tinder::FaradayResponse::WithIndifferentAccess

        builder.basic_auth @options[:username], @options[:password]
        builder.headers["App-Key"] = @options[:key]
        builder.headers["Account-Email"] = @options[:account_email] if @options[:account_email]  
      end
    end

    # probes => [1,2,3] #=> probes => "1,2,3"
    def prepare_params(options)
      options.each do |(key, value)|
        options[key] = Array.wrap(value).map(&:to_s).join(',')
        options[key] = value.to_i if value.acts_like?(:time)
      end

      options
    end

    def get(uri, params = {}, &block)
      response = @connection.get(@connection.build_url(uri, prepare_params(params)), &block)
      update_limits!(response.headers['req-limit-short'], response.headers['req-limit-long'])
      response
    end
    
    def post(uri, params = {})
      @connection.post(@connection.build_url(uri), params)
    end
    
    def delete(uri)
      @connection.delete(@connection.build_url(uri))
    end
    
    def put(uri, params = {})
       @connection.put(@connection.build_url(uri), params)
    end

    def update_limits!(short, long)
      @limit ||= {}
      @limit[:short]  = parse_limit(short)
      @limit[:long]   = parse_limit(long)
      @limit
    end

    # "Remaining: 394 Time until reset: 3589"
    def parse_limit(limit)
      if limit.to_s =~ /Remaining: (\d+) Time until reset: (\d+)/
        { :remaining => $1.to_i,
          :resets_at => $2.to_i.seconds.from_now }
      end
    end

    def test!(options = {})
      Result.parse(self, get("single", options)).first
    end

    def checks(options = {})
      Check.parse(self, get("checks", options))
    end

    def check(id)
      Check.parse(self, get("checks/#{id}")).first
    end
    
    def create_check (params)
       
      if params.has_key?(:name) and params.has_key?(:host) and params.has_key?(:type)
         Check.parse(self, post("checks", params)).first
      else
        raise ArgumentError.new("name, host and type are required parameters")
      end
      
    end

    # Check ID
    def results(id, options = {})
      options.reverse_merge!(:includeanalysis => true)
      Result.parse(self, get("results/#{id}", options))
    end

    def probes(options = {})
      Probe.parse(self, get("probes", options))
    end

    def contacts(options = {})
      Contact.parse(self, get("contacts", options))
    end

    def summary(id)
      Summary.proxy(self, id)
    end

  end
end
