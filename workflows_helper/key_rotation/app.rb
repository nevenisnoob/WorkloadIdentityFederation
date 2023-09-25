require 'googleauth'
# https://github.com/googleapis/google-api-ruby-client
require 'google/apis/iam_v1'
require 'net/http'
require 'uri'
require 'json'
require 'rbnacl'
require 'base64'


# for Test
# bundle exec ruby app.rb #{slack_incoming_webhook} #{project_id} #{today_iam_policies_path} #{yesterday_iam_policies_path} #{resource_diff_json_array}

def get_current_sa_key()
  sa_key = JSON.parse(ENV['GCP_SA_KEY'])
  # puts old_sa_key_json["private_key_id"]
end

def authenticate_with_gcp(current_sa_key)
  authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: StringIO.new(current_sa_key.to_json),
    scope: 'https://www.googleapis.com/auth/cloud-platform')

  # authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
  #     json_key_io: File.open(service_account_key_file),
  #     scope: 'https://www.googleapis.com/auth/cloud-platform')
  # return authorizer
end

# https://googleapis.dev/ruby/google-apis-iam_v1/v0.48.0/Google/Apis/IamV1/IamService.html#create_service_account_key-instance_method
def create_service_account_key(project_id, service_account_email, authorizer)
  iam_service = Google::Apis::IamV1::IamService.new
  iam_service.authorization = authorizer

  key = iam_service.create_service_account_key(
    "projects/#{project_id}/serviceAccounts/#{service_account_email}",
    Google::Apis::IamV1::CreateServiceAccountKeyRequest.new)

  # puts key.name
  # puts key.key_origin #GOOGLE_PROVIDED
  # puts key.key_type #USER_MANAGED
  # puts key.private_key_data #本体。GCP consoleよりkey作成し、downloadしたjsonファイルの中身はこれ。
  # puts key.private_key_type #TYPE_GOOGLE_CREDENTIALS_FILE
  # puts key.public_key_data #KeyはUserで生成し、Googleにupした場合はpublic_key_data取得されると思う
  # ファイルに書き込む
  # File.open('new_service_account_key.json', 'w') do |file|
  #   file.write(key.private_key_data)
  # end
  return key
end

def delete_old_service_account_key(project_id, sa_email, sa_key_id, authorizer)
  iam_service = Google::Apis::IamV1::IamService.new
  iam_service.authorization = authorizer

  iam_service.delete_project_service_account_key(
    "projects/#{project_id}/serviceAccounts/#{sa_email}/keys/#{sa_key_id}"
  )
end


# ref. https://docs.github.com/en/enterprise-server@3.8/rest/actions/secrets#create-or-update-a-repository-secret
def update_github_secret(secret_name, secret_value, repo, owner, personal_access_token)
  public_key = get_public_key(repo, owner, personal_access_token)
  # puts public_key
  encrypt_secret_value = encrypt_secret(public_key["key"], secret_value)
  # puts "encrypted secret value is #{encrypt_secret_value}"

  uri = URI.parse("https://api.github.com/repos/#{owner}/#{repo}/actions/secrets/#{secret_name}")
  request = Net::HTTP::Put.new(uri)
  request["Authorization"] = "Bearer #{personal_access_token}"
  request["Accept"] = "application/vnd.github+json"
  request["X-GitHub-Api-Version"] = "2022-11-28"
  request.body = JSON.dump({
    "encrypted_value" => encrypt_secret_value,
    "key_id" => public_key["key_id"],
  })

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  if response.code == '422'
    puts "Received 422 Unprocessable Entity"
    puts "Response body: #{response.body}"
  end

  return response.code
end

# https://docs.github.com/en/enterprise-server@3.8/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
# https://docs.github.com/en/enterprise-server@3.8/rest/actions/secrets#get-a-repository-public-key
# first create a personal access token, need to be classic, cuz classic PAT has no expiration limit.
# scope: repo
# pat: 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
def get_public_key(repo, owner, personal_access_token)
  uri = URI.parse("https://api.github.com/repos/#{owner}/#{repo}/actions/secrets/public-key")
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{personal_access_token}"
  request["Accept"] = "application/vnd.github+json"

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  return JSON.parse(response.body)
end

# https://docs.github.com/en/enterprise-server@3.10/rest/guides/encrypting-secrets-for-the-rest-api?apiVersion=2022-11-28
# https://rubygems.org/gems/rbnacl
# https://libsodium.gitbook.io/doc/bindings_for_other_languages
# brew install libsodium is necessary
def encrypt_secret(public_key_string, secret_value)
  public_key_bytes = Base64.decode64(public_key_string)

  # binary
  # puts public_key_bytes

  # Create a PublicKey object
  # if you use the public_key_string directly, you will get a error "Public key was 22 bytes (Expected 32)"
  public_key = RbNaCl::PublicKey.new(public_key_bytes)

  # puts public_key

  box = RbNaCl::Boxes::Sealed.from_public_key(public_key)
  encrypted_message = box.encrypt(secret_value)

  # binary
  # puts encrypted_message

  # The encrypted message is in bytes, so we'll encode it to base64 for easier display
  encrypted_message_base64 = Base64.strict_encode64(encrypted_message)
end

gcp_project_id = ARGV[0]
service_account_email = ARGV[1]
personal_access_token = ENV['GITHUB_PAT']
# old_sa_key_file_path = ARGV[2]
# personal_access_token = ARGV[3]


# old_sa_key_file  = File.open(old_sa_key_file_path, 'r')
#
# old_sa_key = old_sa_key_file.read
# old_sa_key_json = JSON.parse(old_sa_key)
#
# puts old_sa_key_json["type"]
# puts old_sa_key_json["project_id"]
# puts old_sa_key_json["private_key_id"]
# puts old_sa_key_json["client_email"]

# gcp認証検証done
current_sa_key = get_current_sa_key()
gcp_authorizer = authenticate_with_gcp(current_sa_key)

# key 生成検証done
new_sa_key = create_service_account_key(gcp_project_id, service_account_email, gcp_authorizer)

# TODO 固定値を外部からもらうようにする
update_key_result = update_github_secret("TERRAFORM_SERVICE_ACCOUNT_KEY", new_sa_key.private_key_data, "WorkloadIdentityFederation", "nevenisnoob", personal_access_token)
puts update_key_result
if update_key_result == 204 || update_key_result == "204"
  result = delete_old_service_account_key(gcp_project_id, service_account_email, current_sa_key["private_key_id"], gcp_authorizer)
  puts "delete old service account key result(): #{result}"
end


# bundle exec ruby app.rb workload-idenity-federation terraform-github@workload-idenity-federation.iam.gserviceaccount.com
# puts public_key

# key 削除検証done
#delete_old_service_account_key(gcp_project_id, service_account_email, old_sa_key_json["private_key_id"], gcp_authorizer)
