require 'auth/oauth2_authenticator'
require 'omniauth-oauth2'

class SlackAuthenticator < ::Auth::OAuth2Authenticator

  CLIENT_ID = ENV['SLACK_CLIENT_ID']
  CLIENT_SECRET = ENV['SLACK_CLIENT_SECRET']

  def name
    'slack'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    raw_info = auth_token["extra"]["raw_info"]

    email = data["email"],
    name = data["email"]
    username = data["nickname"]
    sk_uid = auth_token["uid"]

    current_info = ::PluginStore.get("sk", "sk_uid_#{sk_uid}")

    result.user =
      if current_info
        User.where(id: current_info[:user_id]).first
      end

    result.name = name
    resutl.extra_data = { sk_uid: sk_uid }
    result.email = email

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    ::PluginStore.set("sk", "sk_uid_#{data[:sk_uid]}", {user_id: user.id})
  end

  def register_middleware(omniauth)
    omniauth.provider :slack, CLIENT_ID, CLIENT_SECRET
  end
end

class OmniAuth::Strategies::Slack < OmniAuth::Strategies::OAuth2
  # Give your strategy a name.
  option :name, "slack"

  option :authorize_options, [ :scope, :team ]

  option :client_options, {
    site: "https://slack.com",
    token_url: "/api/oauth.access"
  }

  option :auth_token_params, {
    mode: :query,
    param_name: 'token'
  }

  uid { raw_info['user_id'] }

  info do
    {
      name: user_info['user']['profile']['real_name_normalized'],
      email: user_info['user']['profile']['email'],
      nickname: raw_info['user']
    }
  end

  extra do
    { :raw_info => raw_info, :user_info => user_info }
  end

  def user_info
    @user_info ||= access_token.get("/api/users.info?user=#{raw_info['user_id']}").parsed
  end

  def raw_info
    @raw_info ||= access_token.get("/api/auth.test").parsed
  end
end

auth_provider :title => 'Sign up using Slack',
    :message => 'Log in using your Slack account. (Make sure your popup blocker is disabled.)',
    :frame_width => 920,
    :frame_height => 800,
    :authenticator => SlackAuthenticator.new('slack', trusted: true)