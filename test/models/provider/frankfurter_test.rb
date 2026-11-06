require "test_helper"

class Provider::FrankfurterTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest

  setup do
    @subject = @frankfurter = Provider::Frankfurter.new
  end

  test "returns error response for unsupported currency" do
    VCR.use_cassette("frankfurter/invalid_currency") do
      response = @frankfurter.fetch_exchange_rates(
        from: "USD", to: "XYZ", start_date: Date.parse("01.01.2024"), end_date: Date.parse("05.01.2024")
      )

      assert_not response.success?
      assert_instance_of Provider::Frankfurter::Error, response.error
    end
  end
end
