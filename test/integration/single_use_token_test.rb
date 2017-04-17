require 'test_helper'

class SingleUseTokenTest < Minitest::Test

  def setup
    skip if ENV['SKIP_INTEGRATION'] == 'true' || ENV['PAYSAFE_SUT_API_KEY'] == ''
    turn_off_vcr!

    @sut_client = Paysafe::REST::Client.new do |config|
      config.api_key = ENV['PAYSAFE_SUT_API_KEY']
      config.api_secret = ENV['PAYSAFE_SUT_API_SECRET']
    end
  end

  def test_single_use_token_with_verification_request
    sut = @sut_client.create_single_use_token(
      card: {
        card_num: '5036160000001114',
        card_expiry: {
          month: 12,
          year: 2019
        },
        cvv: '123',
        billing_address: {
          street: 'Z', # trigger AVS MATCH_ZIP_ONLY response
          country: 'US',
          zip: '10014'
        }
      }
    )

    refute_predicate sut.id, :empty?
    refute_predicate sut.payment_token, :empty?
    assert_equal '503616', sut.card.card_bin
    assert_equal '1114', sut.card.last_digits
    assert_equal 12, sut.card.card_expiry.month
    assert_equal 2019, sut.card.card_expiry.year
    assert_equal 'US', sut.billing_address.country
    assert_equal '10014', sut.billing_address.zip

    single_use_token = sut.payment_token

    id = Time.now.to_f.to_s
    result = authenticated_client.create_verification_with_token(merchant_ref_num: id, token: single_use_token)

    refute_predicate result.id, :empty?
    assert_equal id, result.merchant_ref_num
    refute_predicate result.txn_time, :empty?
    assert_equal 'COMPLETED', result.status
    assert_equal 'MD', result.card.type
    assert_equal '1114', result.card.last_digits
    assert_equal 12, result.card.card_expiry.month
    assert_equal 2019, result.card.card_expiry.year
    refute_predicate result.auth_code, :empty?
    assert_equal 'US', result.billing_details.country
    assert_equal '10014', result.billing_details.zip
    assert_equal 'USD', result.currency_code
    assert_equal 'MATCH_ZIP_ONLY', result.avs_response
    assert_equal 'MATCH', result.cvv_verification
  end

  def test_single_use_token_and_redeem_with_create_profile
    sut = @sut_client.create_single_use_token(
      card: {
        card_num: '4111111111111111',
        card_expiry: {
          month: 12,
          year: 2019
        },
        billing_address: {
          country: 'US',
          zip: '10014'
        }
      }
    )

    refute_predicate sut.id, :empty?
    refute_predicate sut.payment_token, :empty?
    assert_equal '411111', sut.card.card_bin
    assert_equal '1111', sut.card.last_digits
    assert_equal 12, sut.card.card_expiry.month
    assert_equal 2019, sut.card.card_expiry.year
    assert_equal 'US', sut.billing_address.country
    assert_equal '10014', sut.billing_address.zip

    id = Time.now.to_f.to_s
    profile = authenticated_client.create_profile_with_token(
      merchant_customer_id: id,
      locale: 'en_US',
      first_name: 'test',
      last_name: 'test',
      email: 'test@test.com',
      card: {
        single_use_token: sut.payment_token,
      }
    )

    assert_equal id, profile.merchant_customer_id
    assert_equal 'en_US', profile.locale
    assert_equal 'test', profile.first_name
    assert_equal 'test', profile.last_name
    assert_equal 'test@test.com', profile.email
    assert_equal 'ACTIVE', profile.status
    refute_predicate profile.payment_token, :empty?

    address = profile.addresses.first
    refute_predicate address.id, :empty?
    assert_equal 'US', address.country
    assert_equal '10014', address.zip
    assert_equal 'ACTIVE', address.status

    card = profile.cards.first
    refute_predicate card.id, :empty?
    assert_equal 12, card.card_expiry.month
    assert_equal 2019, card.card_expiry.year
    assert_equal 'ACTIVE', card.status
    refute_predicate card.billing_address_id, :empty?
  end

  def test_single_use_token_and_redeem_with_create_card
    sut = @sut_client.create_single_use_token(
      card: {
        card_num: '4111111111111111',
        card_expiry: {
          month: 12,
          year: 2019
        },
        billing_address: {
          country: 'US',
          zip: '10014'
        }
      }
    )

    refute_predicate sut.id, :empty?
    refute_predicate sut.payment_token, :empty?
    assert_equal '411111', sut.card.card_bin
    assert_equal '1111', sut.card.last_digits
    assert_equal 12, sut.card.card_expiry.month
    assert_equal 2019, sut.card.card_expiry.year
    assert_equal 'US', sut.billing_address.country
    assert_equal '10014', sut.billing_address.zip

    profile = authenticated_client.create_profile(
      merchant_customer_id: Time.now.to_f.to_s,
      locale: 'en_US'
    )

    card = authenticated_client.create_card_with_token(profile.id, token: sut.payment_token)

    refute_predicate card.id, :empty?
    refute_predicate card.payment_token, :empty?
    assert_equal '411111', sut.card.card_bin
    assert_equal '1111', sut.card.last_digits
    assert_equal 12, card.card_expiry.month
    assert_equal 2019, card.card_expiry.year
    assert_equal 'ACTIVE', card.status
    refute_predicate card.billing_address_id, :empty?
  end

end
