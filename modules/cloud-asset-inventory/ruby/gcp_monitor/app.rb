require 'json'
require 'hashdiff'
require 'slack-notifier'
require 'set'

PROJECT_ID="workload-idenity-federation"

puts "project id : #{PROJECT_ID}"

def gcp_resources_modification_summary(resources_data)
  resources_array = []
  # TODO change projectId
  resources_array.push(slack_block_header("#{PROJECT_ID} 最近変更にあったResources"))
  if !resources_data
    resource_markdown_text = "*なし*"
    resources_array.push(slack_block_section(resource_markdown_text))
    resources_array.push(slack_block_divider())
    return resources_array
  end
  resources_json = JSON.parse(resources_data)
  if resources_json.empty?
    resource_markdown_text = "*なし*"
    resources_array.push(slack_block_section(resource_markdown_text))
    resources_array.push(slack_block_divider())
  else
    resources_json.each do |resource|
      resource_markdown_text = ""
      resource_markdown_text+="*name*: #{resource["name"]}\n"
      resource_markdown_text+="*assetType*: #{resource["assetType"]}\n"
      resource_markdown_text+="*displayName*: #{resource["displayName"]}\n"
      resource_markdown_text+="*project*: #{resource["project"]}\n"
      resource_markdown_text+="*createTime*: #{resource["createTime"]}\n"
      resource_markdown_text+="*updateTime*: #{resource["updateTime"]}\n"
      resources_array.push(slack_block_section(resource_markdown_text))
      resources_array.push(slack_block_divider())
    end
  end
  resources_array
end

def gcp_iam_policies_modification_summary(iam_policies_path)
  # 今日の日付を取得
  today = Date.today
  # 昨日の日付を取得
  yesterday = today - 1

  # 日付を指定された形式にフォーマット
  formatted_today = today.strftime('%Y-%m-%d')
  formatted_yesterday = yesterday.strftime('%Y-%m-%d')

  puts "Today: #{formatted_today}"
  puts "Yesterday: #{formatted_yesterday}"

  # original(old)
  file_name_yesterday = File.join(iam_policies_path, "iam-policies-#{formatted_yesterday}.json")
  # new
  file_name_today = File.join(iam_policies_path, "iam-policies-#{formatted_today}.json")

  # get yesterday's iam policies json data
  file_yesterday = File.open(file_name_yesterday, 'r')
  json_content_yesterday = file_yesterday.read
  json_data_yesterday = JSON.parse(json_content_yesterday)
  puts "json_data_yesterday: #{json_data_yesterday}"

  # get today's iam policies json data
  file_today = File.open(file_name_today, 'r')
  json_content_today = file_today.read
  json_data_today = JSON.parse(json_content_today)
  puts "json_data_today: #{json_data_today}"

  iam_policies_diff = Hashdiff.diff(json_data_yesterday, json_data_today)

  puts iam_policies_diff

  diff_set_plus = Set.new
  diff_set_minus = Set.new

  iam_policies_array = []
  iam_policies_array.push(slack_block_header("#{PROJECT_ID} 最近変更にあったIAM Policies"))

  # JSON配列をループしてクエリを実行
  if iam_policies_diff.empty?
    iam_policy_markdown_text = "*なし*"
    iam_policies_array.push(slack_block_section(iam_policy_markdown_text))
    iam_policies_array.push(slack_block_divider())
  else
    iam_policies_diff.each do |iam_policy_diff|
      sub_strings = iam_policy_diff[1].split('.')
      # 文字列から整数を取得
      index = sub_strings[0].gsub(/\D/, '').to_i
      if iam_policy_diff[0] == "-"
        iam_policy_markdown_text = ""
        iam_policy_markdown_text+="*assetType*: #{json_data_yesterday[index]["assetType"]}\n"
        iam_policy_markdown_text+="*resource*: #{json_data_yesterday[index]["resource"]}\n"
        iam_policy_markdown_text+="に変更がありました。変更内容は以下：\n"
        iam_policy_markdown_text+="```#{iam_policy_diff}```\n"
        iam_policies_array.push(slack_block_section(iam_policy_markdown_text))
      else
        iam_policy_markdown_text = ""
        iam_policy_markdown_text+="*assetType*: #{json_data_today[index]["assetType"]}\n"
        iam_policy_markdown_text+="*resource*: #{json_data_today[index]["resource"]}\n"
        iam_policy_markdown_text+="に変更がありました。変更内容は以下：\n"
        iam_policy_markdown_text+="```#{iam_policy_diff}```\n"
        iam_policies_array.push(slack_block_section(iam_policy_markdown_text))
      end
      iam_policies_array.push(slack_block_divider())
    end
  end
  iam_policies_array
end

def slack_block_header(title)
  {
    "type": "header",
  	"text": {
      "type": "plain_text",
  	   "text": ":star:#{title}",
  	    "emoji": true
  	}
  }
end

def slack_block_divider()
  {
    "type": "divider"
  }
end

def slack_block_section(text)
  {
    "type": "section",
    "text": {
      "type": "mrkdwn",
      "text": "#{text}"
    }
  }
end

# we can not include slack incoming webhook in sourcecode for security reasons,
# also the webhook would be revoked immediately when you commit it to github(interesting spec.)
slack_endpoint = ARGV[0]
new_iam_policies_path = ARGV[1]
old_iam_policies_path = ARGV[2]
resources_diff = ARGV[3]

puts "newest iam policies path is #{new_iam_policies_path}"
puts "old iam policies path is #{old_iam_policies_path}"
puts "resources_diff is #{resources_diff}"

resources_info = gcp_resources_modification_summary(resources_diff)
# iam_policies_info = gcp_iam_policies_modification_summary()
iam_policies_info = []
asset_modification_summary = resources_info + iam_policies_info

notifier = Slack::Notifier.new slack_endpoint
notifier.post(blocks: asset_modification_summary)

# for Test
# bundle exec ruby app.rb #{slack_incoming_webhook} #{today_iam_policies_path} #{yesterday_iam_policies_path} #{resource_diff_json_array}
