class Provider::Frankfurter < Provider
  include ExchangeRateConcept, SecurityConcept

  # Subclass so errors caught in this provider are raised as Provider::Frankfurter::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  InvalidSecurityPriceError = Class.new(Error)

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      response = client.get("#{base_url}/v2/rates") do |req|
        req.params["base"] = from
        req.params["quotes"] = to
        req.params["from"] = date
      end

      rate = JSON.parse(response.body).dig("rate")

      Rails.logger.debug("Fetching rate #{rate} for base #{from} and quote #{to}")

      Rate.new(date: date.to_date, from:, to:, rate:)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      data = client.get("#{base_url}/v2/rates") do |req|
        req.params["base"] = from
        req.params["quotes"] = to
        req.params["from"] = start_date.to_s
        req.params["to"] = end_date.to_s
      end

      data.map do |rate|
        date = rate.dig("date")
        rate = rate.dig("rate")

        if date.nil? || rate.nil?
          Rails.logger.warn("#{self.class.name} returned invalid rate data for pair from: #{from} to: #{to} on: #{date}.  Rate data: #{rate.inspect}")
          Sentry.capture_exception(InvalidExchangeRateError.new("#{self.class.name} returned invalid rate data"), level: :warning) do |scope|
            scope.set_context("rate", { from: from, to: to, date: date })
          end

          next
        end

        Rate.new(date: date.to_date, from:, to:, rate:)
      end.compact
    end
  end

  private
    def base_url
      ENV["FRANKFURTER_URL"] || "https://api.frankfurter.dev"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.response :raise_error
      end
    end
end
