require 'test_helper'

class PaysafeTest < Minitest::Test

  def setup
    turn_on_vcr!
  end

  def teardown
    turn_off_vcr!
  end

  def test_that_it_has_a_version_number
    refute_nil ::Paysafe::VERSION
  end

  def test_get_profile
    result = VCR.use_cassette('get_profile') do
      profile = authenticated_client.customer_vault.create_profile(
        merchant_customer_id: random_id,
        locale: 'en_US',
        first_name: 'test',
        last_name: 'test',
        email: 'test@test.com'
      )
      authenticated_client.customer_vault.get_profile(id: profile.id)
    end

    assert_match UUID_REGEX, result.id
    assert_equal 'ACTIVE', result.status
    assert_equal 'en_US', result.locale
    assert_equal 'test', result.first_name
    assert_equal 'test', result.last_name
    assert_equal 'test@test.com', result.email
    refute_predicate result.merchant_customer_id, :empty?
    refute_predicate result.payment_token, :empty?
  end

  def test_get_profile_with_fields
    profile = VCR.use_cassette('get_profile_with_cards_and_addresses') do
      result = authenticated_client.customer_vault.create_profile(
        merchant_customer_id: random_id,
        locale: 'en_US',
        first_name: 'test',
        last_name: 'test',
        email: 'test@test.com',
        card: {
          card_num: '4111111111111111',
          card_expiry: {
            month: 12,
            year: 2050
          },
          billing_address: {
            country: 'US',
            zip: '10014'
          }
        }
      )
      authenticated_client.customer_vault.get_profile(id: result.id, fields: [:cards,:addresses])
    end

    assert_match UUID_REGEX, profile.id
    assert_match UUID_REGEX, profile.merchant_customer_id
    assert profile.merchant_customer_id?
    assert_match TOKEN_REGEX, profile.payment_token
    assert profile.payment_token?
    assert_equal 'ACTIVE', profile.status
    assert_equal 'en_US', profile.locale
    assert_equal 'test', profile.first_name
    assert_equal 'test', profile.last_name
    assert_equal 'test@test.com', profile.email

    card = profile.cards.first
    assert_match UUID_REGEX, card.id
    assert_equal '411111', card.card_bin
    assert_equal '1111', card.last_digits
    assert_equal 'VI', card.card_type
    assert_equal 'visa', card.brand
    assert_equal 12, card.card_expiry.month
    assert_equal 2050, card.card_expiry.year
    assert_match UUID_REGEX, card.billing_address_id
    assert_match TOKEN_REGEX, card.payment_token
    assert_equal 'ACTIVE', card.status

    address = profile.addresses.first
    assert_match UUID_REGEX, address.id
    assert_equal 'US', address.country
    assert_equal '10014', address.zip
    assert_equal 'ACTIVE', address.status
  end

  def test_create_profile
    result = VCR.use_cassette('create_profile') do
      authenticated_client.customer_vault.create_profile(
        merchant_customer_id: random_id,
        locale: 'en_US',
        first_name: 'test',
        last_name: 'test',
        email: 'test@test.com'
      )
    end

    assert_match UUID_REGEX, result.merchant_customer_id
    assert_equal 'en_US', result.locale
    assert_equal 'test', result.first_name
    assert_equal 'test', result.last_name
    assert_equal 'test@test.com', result.email
    assert_equal 'ACTIVE', result.status
    assert result.payment_token?
  end

  def test_create_profile_failed
    error = assert_raises(Paysafe::Error::BadRequest) do
      VCR.use_cassette('create_profile_failed') do
        authenticated_client.customer_vault.create_profile(
          merchant_customer_id: '',
          locale: ''
        )
      end
    end

    assert_equal '5068', error.code
    assert_equal 'Either you submitted a request that is missing a mandatory field or the value of a field does not match the format expected.', error.message
  end

  def test_create_profile_with_card_and_address
    profile = VCR.use_cassette('create_profile_with_card_and_address') do
      authenticated_client.customer_vault.create_profile(
        merchant_customer_id: random_id,
        locale: 'en_US',
        first_name: 'test',
        last_name: 'test',
        email: 'test@test.com',
        card: {
          card_num: '4111111111111111',
          card_expiry: {
            month: 12,
            year: 2050
          },
          billing_address: {
            country: 'US',
            zip: '10014'
          }
        }
      )
    end

    assert profile.id?
    assert_match UUID_REGEX, profile.merchant_customer_id
    assert_equal 'ACTIVE', profile.status
    assert_equal 'en_US', profile.locale
    assert_equal 'test', profile.first_name
    assert_equal 'test', profile.last_name
    assert_equal 'test@test.com', profile.email
    assert_match TOKEN_REGEX, profile.payment_token

    card = profile.cards.first
    assert_match UUID_REGEX, card.id
    assert_equal '411111', card.card_bin
    assert_equal '1111', card.last_digits
    assert_equal 'VI', card.card_type
    assert_equal 'visa', card.brand
    assert_equal 12, card.card_expiry.month
    assert_equal 2050, card.card_expiry.year
    assert_match UUID_REGEX, card.billing_address_id
    assert_match TOKEN_REGEX, card.payment_token
    assert_equal 'ACTIVE', card.status

    address = profile.addresses.first
    assert_match UUID_REGEX, address.id
    assert_equal 'US', address.country
    assert_equal '10014', address.zip
    assert_equal 'ACTIVE', address.status
  end

  def test_update_profile
    profile = VCR.use_cassette('update_profile') do
      profile = create_empty_profile
      assert_match UUID_REGEX, profile.id
      assert_nil profile.first_name
      assert_nil profile.last_name
      assert_nil profile.email

      authenticated_client.customer_vault.update_profile(
        id: profile.id,
        merchant_customer_id: random_id,
        locale: 'en_US',
        first_name: 'Testing',
        last_name: 'Testing',
        email: 'example@test.com'
      )
    end

    assert_match UUID_REGEX, profile.id
    assert_match UUID_REGEX, profile.merchant_customer_id
    assert_equal 'en_US', profile.locale
    assert_equal 'Testing', profile.first_name
    assert_equal 'Testing', profile.last_name
    assert_equal 'example@test.com', profile.email
    assert_equal 'ACTIVE', profile.status
    assert_match TOKEN_REGEX, profile.payment_token
  end

  def test_create_address
    result = VCR.use_cassette('create_address') do
      profile = create_empty_profile
      authenticated_client.customer_vault.create_address(
        profile_id: profile.id,
        country: 'US',
        zip: '10014'
      )
    end

    assert_match UUID_REGEX, result.id
    assert_equal 'US', result.country
    assert_equal '10014', result.zip
    assert_equal 'ACTIVE', result.status
  end

  def test_delete_address
    VCR.use_cassette('delete_address') do
      profile = create_empty_profile
      address = authenticated_client.customer_vault.create_address(
        profile_id: profile.id,
        country: 'US',
        zip: '10014'
      )

      authenticated_client.customer_vault.delete_address(
        profile_id: profile.id,
        id: address.id
      )
    end
  end

  def test_update_address
    result = VCR.use_cassette('update_address') do
      profile = create_empty_profile
      address = authenticated_client.customer_vault.create_address(
        profile_id: profile.id,
        country: 'US',
        zip: '10014'
      )

      authenticated_client.customer_vault.update_address(
        profile_id: profile.id,
        id: address.id,
        country: 'US',
        zip: '10018'
      )
    end

    assert_match UUID_REGEX, result.id
    assert_equal 'US', result.country
    assert_equal '10018', result.zip
    assert_equal 'ACTIVE', result.status
  end

  def test_create_card
    card = VCR.use_cassette('create_card') do
      profile = create_empty_profile

      address = authenticated_client.customer_vault.create_address(
        profile_id: profile.id,
        country: 'US',
        zip: '10014'
      )

      authenticated_client.customer_vault.create_card(
        profile_id: profile.id,
        number: '4111111111111111',
        month: 12,
        year: 2050,
        billing_address_id: address.id
      )
    end

    assert_match UUID_REGEX, card.id
    assert_equal '411111', card.card_bin
    assert_equal '1111', card.last_digits
    assert_equal 'VI', card.card_type
    assert_equal 'visa', card.brand
    assert_equal 12, card.card_expiry.month
    assert_equal 2050, card.card_expiry.year
    assert_match UUID_REGEX, card.billing_address_id
    assert_equal 'ACTIVE', card.status
    assert_match TOKEN_REGEX, card.payment_token
  end

  def test_create_card_failed_400
    error = assert_raises(Paysafe::Error::BadRequest) do
      VCR.use_cassette('create_card_failed_bad_request') do
        profile = create_empty_profile
        authenticated_client.customer_vault.create_card(
          profile_id: profile.id,
          number: '4111111111',
          month: 12,
          year: 2017
        )
      end
    end

    assert_equal "5068", error.code
    assert_equal 'Either you submitted a request that is missing a mandatory field or the value of a field does not match the format expected.', error.message
    assert error.response[:error][:field_errors].any?
  end

  def test_create_card_failed_409
    error = assert_raises(Paysafe::Error::Conflict) do
      VCR.use_cassette('create_card_failed_conflict') do
        profile = create_empty_profile
        authenticated_client.customer_vault.create_card(
          profile_id: profile.id,
          number: '4111111111111111',
          month: 12,
          year: 2050
        )

        # Should fail since card already exists
        authenticated_client.customer_vault.create_card(
          profile_id: profile.id,
          number: '4111111111111111',
          month: 12,
          year: 2050
        )
      end
    end

    assert_equal "7503", error.code
    assert_match(/Card number already in use -/, error.message)
  end

  def test_delete_card
    VCR.use_cassette('delete_card') do
      profile = create_empty_profile

      address = authenticated_client.customer_vault.create_address(
        profile_id: profile.id,
        country: 'US',
        zip: '10014'
      )

      card = authenticated_client.customer_vault.create_card(
        profile_id: profile.id,
        number: '4111111111111111',
        month: 12,
        year: 2050,
        billing_address_id: address.id
      )

      authenticated_client.customer_vault.delete_card(profile_id: profile.id, id: card.id)
    end
  end

  def test_get_card
    card = VCR.use_cassette('get_card') do
      profile = create_empty_profile

      address = authenticated_client.customer_vault.create_address(
        profile_id: profile.id,
        country: 'US',
        zip: '10014'
      )

      card = authenticated_client.customer_vault.create_card(
        profile_id: profile.id,
        number: '4111111111111111',
        month: 12,
        year: 2050,
        billing_address_id: address.id
      )

      authenticated_client.customer_vault.get_card(profile_id: profile.id, id: card.id)
    end

    assert_match UUID_REGEX, card.id
    assert_equal '411111', card.card_bin
    assert_equal '1111', card.last_digits
    assert_equal 'VI', card.card_type
    assert_equal 'visa', card.brand
    assert_equal 12, card.card_expiry.month
    assert_equal 2050, card.card_expiry.year
    assert_match UUID_REGEX, card.billing_address_id
    assert_equal 'ACTIVE', card.status
    assert_match TOKEN_REGEX, card.payment_token
  end

  def test_update_card
    card = VCR.use_cassette('update_card') do
      profile = create_empty_profile

      address = authenticated_client.customer_vault.create_address(
        profile_id: profile.id,
        country: 'US',
        zip: '10014'
      )

      card = authenticated_client.customer_vault.create_card(
        profile_id: profile.id,
        number: '4111111111111111',
        month: 12,
        year: 2050,
        billing_address_id: address.id
      )

      authenticated_client.customer_vault.update_card(
        profile_id: profile.id,
        id: card.id,
        month: 6,
        year: 2055
      )
    end

    assert_match UUID_REGEX, card.id
    assert_equal '411111', card.card_bin
    assert_equal '1111', card.last_digits
    assert_equal 'VI', card.card_type
    assert_equal 'visa', card.brand
    assert_equal 6, card.card_expiry.month
    assert_equal 2055, card.card_expiry.year
    assert_nil card.billing_address_id
    assert_equal 'ACTIVE', card.status
    assert_match TOKEN_REGEX, card.payment_token
  end

end
