require "discordrb"
require "yaml"
require "leveldb"
require "json"

config = YAML.load(File.read("config.yaml"))
$db = LevelDB::DB.new config["db"]

Kaneki = Discordrb::Bot.new token: config["token"]

$prefix = config["prefix"]

Kaneki.message do |e|
	if e.message.content.start_with? $prefix
		command_handler e
	else
		db_handler e
	end
end

def get_db id
	db_entry = $db[id.to_s]
	if db_entry
		hash = JSON.parse(db_entry)
		hash.default = 0
		return hash
	else
		return Hash.new(0)
	end
end

def command_handler e
	
	args = e.message.content[$prefix.length..].split " "
	command = args.shift

	case command
	when "word"
		return e.respond ":x: Missing word argument" if args.length < 1
		
		id = get_db e.author.id
		mention = false

		# Mention
		if /<@!?(\d{18})>/.match? args[0]
			id = /<@!?(\d{18})>/.match(args.shift).captures[0].to_i
			mention = true
		end

		db_entry = get_db id
		output = if mention then 
			"<@#{id}> has said\n"
		else
			"You have said\n"
		end
		args.each {|word| output << "#{word}: #{db_entry[word]} times\n"}

		e.respond(output)
	when "most"
		id = e.author.id
		mention = args.length > 0

		if mention
			begin
				id = /<@!?(\d{18})>/.match(args.shift).captures[0].to_i
			rescue
				return e.respond ":x: Bad mention"
			end
		end

		db_entry = get_db id
		most = db_entry.max_by{|k,v|v}

		if !most
			return e.respond "This person hasn't said anything yet"
		end

		e.respond("\"#{most[0]}\" (#{most[1]} times)")
	when "help"
		e.respond("For now try using 'word' or 'most'")
	end
end

def db_handler e
	content = e.message.content
	author = e.author.id

	words = content.split " "

	db_entry = get_db author

	words.each { |word| db_entry[word] += 1}

	$db[author.to_s] = JSON.fast_generate db_entry
end

Kaneki.run