require 'telegram/bot'
require 'sqlite3'
require 'yaml'

TOKEN = YAML.load_file('env.yml')['API_TOKEN']
DB = SQLite3::Database.new 'database.db'

def welcome(bot, _commands, message)
  text = <<-EOL
你好 #{message.from.first_name}，歡迎使用三界八綱 Bot。

本 Bot 支持的指令如下：

  /q [食物名稱/域/界/綱/目/科/屬] 輸入生物名稱的生物分類信息或反查符合條件的生物。
  /id [ID 編號] 根據 ID 編號查詢生物詳情。
  /calc [食物名稱（按空格隔開）] 根據 ID 計算配餐一共有幾界幾綱。

例如：
  /q 雙歧桿菌

如有問題，歡迎反饋至 dsh0416，數據庫由 ngiamzsjit 整理。
  EOL
  bot.api.send_message(chat_id: message.chat.id, text: text)
end

def query(bot, commands, message)
  if commands.length < 2
    bot.api.send_message(chat_id: message.chat.id, text: '指令無法識別')
    welcome(bot, commands, message)
    return
  end

  filters = commands[1..-1].reject(&:nil?).reject(&:empty?)
  clause = filters.map do |name|
    "search LIKE '%' || ? || '%'"
  end.join(' AND ')

  results = DB.execute(
    "SELECT id, taxonomy FROM taxonomy WHERE #{clause}",
    filters
  )

  if results.length == 0
    bot.api.send_message(chat_id: message.chat.id, text: '找不到相關資料，請嘗試其它關鍵詞')
    return
  end

  bot.api.send_message(chat_id: message.chat.id, text: "你好 #{message.from.first_name}，找到 #{results.length} 筆資料。")
  if results.length > 30
    bot.api.send_message(chat_id: message.chat.id, text: "資料筆數過多，顯示前 30 筆。")
    results = results[0...30]
  end

  lists = results.map do |result|
    "ID: #{result[0]}, #{result[1]}"
  end

  lists.each_slice(10).each do |sub_list|
    bot.api.send_message(chat_id: message.chat.id, text: sub_list.join("\n\n"))
  end

  bot.api.send_message(chat_id: message.chat.id, text: "你可以使用 /id [ID 編號] 指令根據 ID 編號查詢生物詳情。")
end

def query_by_id(bot, commands, message)
  if commands.length < 2
    bot.api.send_message(chat_id: message.chat.id, text: '指令無法識別')
    welcome(bot, commands, message)
    return
  end

  id = commands[1].to_i
  results = DB.execute('select id, chinese_name, english_name, japanese_name, taxonomy from taxonomy where id = ?;', [id])

  if results.length == 0
    bot.api.send_message(chat_id: message.chat.id, text: '無法找到此 ID')
    return
  end

  result = results[0]
  text = <<-EOL
你好 #{message.from.first_name}，找到 ID: #{id} 的對應資料。

ID: #{result[0]}
中文名: #{result[1] || '未收錄'}
英文名: #{result[2] || '未收錄'}
日文名: #{result[3] || '未收錄'}

#{result[4]}
    EOL
    bot.api.send_message(chat_id: message.chat.id, text: text)
end

def calc(bot, commands, message)
  if commands.length < 2
    bot.api.send_message(chat_id: message.chat.id, text: '指令無法識別')
    welcome(bot, commands, message)
    return
  end

  filters = commands[1..-1].reject(&:nil?).reject(&:empty?)
  clause = filters.map do |name|
    "chinese_name = ?"
  end.join(' OR ')

  results = DB.execute(
    "SELECT id, chinese_name, kingdom, class FROM taxonomy WHERE #{clause}",
    filters
  )

  if results.length == 0
    bot.api.send_message(chat_id: message.chat.id, text: '找不到相關資料，請嘗試其它關鍵詞')
    return
  end

  lists = results.map do |result|
    "ID: #{result[0]}, #{result[1]}, #{result[2]}, #{result[3]}"
  end

  text = <<-EOL
你好 #{message.from.first_name}，找到 #{results.length} 筆資料。
共 #{results.map{|t| t[2]}.uniq.length} 界 #{results.map{|t| t[3]}.uniq.length} 綱。
  EOL
  bot.api.send_message(chat_id: message.chat.id, text: text)
  lists.each_slice(10).each do |sub_list|
    bot.api.send_message(chat_id: message.chat.id, text: sub_list.join("\n"))
  end
end

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    p message
    text = message.text
    text = text[0...-21] if text.end_with? '@kingdoms_classes_bot'

    commands = text.split

    case commands[0]
    when '/start'
      welcome(bot, commands, message)
    when '/q'
      query(bot, commands, message)
    when '/id'
      query_by_id(bot, commands, message)
    when '/calc'
      calc(bot, commands, message)
    else
      bot.api.send_message(chat_id: message.chat.id, text: '指令無法識別')
      welcome(bot, commands, message)
    end

  rescue => e
    puts "[Error] #{e}"
    bot.api.send_message(chat_id: message.chat.id, text: '指令無法識別')
    welcome(bot, commands, message)
  end
end
