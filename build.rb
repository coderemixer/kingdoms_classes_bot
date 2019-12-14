require 'sqlite3'
require 'csv'
require 'ropencc'

File.delete('database.db') if File.exist?('database.db')

db = SQLite3::Database.new 'database.db'

# Create a table
# 中,英文,日文,原產地,養殖/種植,生境,食用部位,食物種類,,域,,界,,門,,亞門,,綱,,亞綱,,目,,科,,亞科,,屬,,種,,

db.execute <<-SQL
  create table taxonomy (
    id integer primary key,
    chinese_name text,
    english_name text,
    japanese_name text,

    kingdom text not null,
    class text not null,

    taxonomy text,
    search text
  );
SQL

CSV.foreach('raw_data.csv', headers: true, encoding: 'utf-8') do |row|
  search = row[0...-1].reject(&:nil?).reject(&:empty?).join(' ')

  db.execute(
    'insert into taxonomy (chinese_name, english_name, japanese_name, kingdom, class, taxonomy, search) values ( ?, ?, ?, ?, ?, ?, ?)',
    [
      row['中'],
      row['英文'],
      row['日文'],
      row[11] || row[13], # 不夠用門
      row[17] || row[21], # 綱不夠用目補
      row[-1],
      "#{search} #{Ropencc.conv('t2s.json', search)}"
    ]
  )
end
