require 'omniauth-oauth2'
require 'multi_json'

module OmniAuth
  module Strategies
    class EOCustom < OmniAuth::Strategies::OAuth2
      option :name, 'eo_custom'

      option :client_options,
             authentication_url: 'MUST_BE_PROVIDED',
             site: 'https://api.eonetwork.org',
             client_id: 'MUST_BE_PROVIDED',
             secret_key: 'MUST_BE_PROVIDED',
             username: 'MUST_BE_PROVIDED',
             password: 'MUST_BE_PROVIDED'

      uid { @member_id }

      info do
        {
          first_name: raw_member_info[:FirstName],
          last_name: raw_member_info[:LastName],
          email: raw_member_info[:Email],
          username: raw_member_info[:Nickname],
          member_id: raw_member_info[:MemberId],
          custom_fields_data: custom_fields_data
        }
      end

      def request_phase
        redirect "#{authentication_url}?clientid=#{client_id}"
      end

      def callback_phase
        self.access_token = { token: request.params['token'] }
        validate_signature

        uri = "/v2/LoginSrv/Authenticate/?clientId=#{client_id}&token=#{access_token[:token]}&apiSig=#{request.params['apiSig']}"
        response = connection.get(uri) { |request| request.headers['Authorization'] = encode_text(endpoint + uri) }

        if response.success?
          data = to_json(response.body)
          @member_id = data[:MemberId]
          @member_token = data[:MemberToken]
          self.env['omniauth.auth'] = auth_hash
          self.env['omniauth.origin'] = '/' + request.params['origin']
          call_app!
        else
          fail!(:invalid_credentials)
        end
      end

      def auth_hash
        AuthHash.new(proivder: name, uid: uid, info: info)
      end

      private

      def authentication_url
        options.client_options.authentication_url
      end

      def client_id
        options.client_options.client_id
      end

      def endpoint
        options.client_options.site
      end

      def password
        options.client_options.password
      end

      def secret_key
        options.client_options.secret_key
      end

      def username
        options.client_options.username
      end

      def connection
        Faraday.new(url: endpoint) do |request|
          request.headers['Accept'] = 'application/json'
          request.adapter(Faraday.default_adapter)
        end
      end

      def fetch_member_details
        uri = "/v2/MemberSrv/GetMemberDetail/?clientId=#{client_id}&token=#{@member_token}&memberId=#{@member_id}"
        response = connection.get(uri) { |request| request.headers['Authorization'] = encode_text(endpoint + uri) }

        if response.success?
          to_json(response.body)
        else
          fail!(:invalid_credentials)
        end
      end

      def custom_fields_data
        auth_response = authenticate

        if auth_response.success?
          token = to_json(auth_response.body)[:access_token]
          member_info(token)
        else
          fail!(:invalid_credentials)
        end
      end

      def member_info(token)
        response = connection.get('/v3/eo-members') do |request|
          request.headers['Authorization'] = "Bearer #{token}"
          request.params['ClientId'] = client_id
          request.params['user_id'] = @member_id
        end

        if response.success?
          data = to_json(response.body).first

          {
            region: data[:RegionName],
            country: data[:BusinessCountry],
            gender: data[:Gender],
            birthday: data[:BirthDate]
          }
        else
          fail!(:invalid_credentials)
        end
      end

      def authenticate
        connection.post('/v3/Authenticate') do |request|
          request.body = "grant_type=password&client_id=#{client_id}&username=#{username}&password=#{password}"
        end
      end

      def encode_text(text)
        key = Base64.decode64(secret_key)
        hmac = OpenSSL::HMAC.digest('md5', key, text)
        Base64.encode64(hmac).strip
      end

      def raw_member_info
        @raw_member_info ||= fetch_member_details
      end

      def to_json(raw)
        MultiJson.load(raw, symbolize_keys: true)
      end

      def validate_signature
        reference = encode_text(request.params['userName'] + access_token[:token])
        fail!(:invalid_credentials) unless reference.eql?(request.params['sig'])
      end
    end
  end
end
