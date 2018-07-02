# frozen_string_literal: true

require 'multi_json'
require 'jwt'
require 'omniauth/strategies/oauth2'
require 'uri'
require "oauth2"

module OmniAuth
  module Strategies
    class Kubex < OmniAuth::Strategies::OAuth2
      option :name, :kubex
      option :callback_url
      option :domain, 'barong.io'
      option :use_https, true

      option :api_version, 'v1'

      option  :authorize_url, '/oauth/authorize'
      option  :raw_info_url

      class Cont
        class Req
          def initialize (co_hash, auth)
            @hash = co_hash
            @auth = auth
          end
          def parameters
            @hash
          end
          def authorization
            @auth
          end
        end
        def initialize (co_hash, auth)
          @req = Req.new co_hash, auth
        end
        def request
          @req
        end
      end

      args [
          :client_id,
          :client_secret,
          :domain
      ]

      def client
        options.client_options.site = domain_url
        options.client_options.authorize_url = options.authorize_url
        options.client_options.redirect_uri = callback_url
        super
      end

      def domain_url
        domain_url = URI(options.domain)
        domain_url = URI("#{scheme}://#{domain_url}") unless domain_url.class.in? ([URI::HTTP, URI::HTTPS])
        domain_url.to_s
      end


      uid { raw_info['uid'] }

      info do
        {
            email:  raw_info['email'],
            role:   raw_info['role'],
            level:  raw_info['level'],
            state:  raw_info['state']
        }
      end

      def raw_info
        if ENV['BARONG_DOMAIN'].blank? || (ENV.fetch('BARONG_DOMAIN') == ENV.fetch('URL_HOST'))
          @raw_info ||= env['warden'].authenticate(scope: :identity_account)
        end
        @raw_info ||= access_token.get(raw_info_url).parsed
      end

      def raw_info_url
        options.raw_info_url || "/api/#{options.api_version}/accounts/me"
      end

      def callback_url
        options.callback_url || (full_host + script_name + callback_path)
      end

      protected
      def build_access_token
        if ENV['BARONG_DOMAIN'].blank? || (ENV.fetch('BARONG_DOMAIN') == ENV.fetch('URL_HOST'))
          out_par = {}
          aut_var = ::OAuth2::Authenticator.encode_basic_auth options.client_id, options.client_secret
          opt_has = {:grant_type => 'authorization_code', :code =>  request.params["code"], :redirect_uri => callback_url,:symbolize_keys => true}
          @req_obj = Cont.new opt_has, aut_var
          @door_server ||= Doorkeeper::Server.new @req_obj
          @tok_strategy ||= Doorkeeper::Request::AuthorizationCode.new @door_server
          @authorize_response ||= @tok_strategy.authorize
          build_access_token_client@authorize_response, opt_has,::OAuth2::AccessToken
        else
          super
        end
      end
      private
      def scheme
        options.use_https ? 'https' : 'http'
      end

      def build_access_token_client(response, access_token_opts, access_token_class)
        access_token_class.from_hash(client, response.body.merge(access_token_opts)).tap do |access_token|
          access_token.response = response if access_token.respond_to?(:response=)
        end
      end
    end
  end
end
