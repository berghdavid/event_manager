require "csv"
require "google/apis/civicinfo_v2"
require "erb"
require "date"

civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

def clean_zipcode(zipcode)
    zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(number)
    nr = number.gsub(/[()-.]/, "")

    if(nr.length == 11 && nr[0] == 1)
        nr.shift(1)
    elsif(nr.length != 10)
        nr = "Missing homephone number"
    end
    return nr
end

def prime_reg_hour(regtimes)
    hour_created = Hash.new(0)
    regtimes.each do |regtime|
        date = DateTime.strptime(regtime, '%m/%d/%y %k:%M')
        hour_created[date.hour] += 1
    end
    return hour_created.key(hour_created.values.max)
end

def prime_reg_day(regtimes)
    day_created = Hash.new(0)
    regtimes.each do |regtime|
        date = DateTime.strptime(regtime, '%m/%d/%y %k:%M')
        day_created[date.wday] += 1
    end
    day_nr = day_created.key(day_created.values.max)
    return Date::DAYNAMES[day_nr]
end

def legislators_by_zipcode(zip)
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  
    begin
        civic_info.representative_info_by_address(
            address: zip,
            levels: 'country',
            roles: ['legislatorUpperBody', 'legislatorLowerBody']
          ).officials
    rescue
      "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
    end
end

def save_thank_you_letter (id, form_letter)
    Dir.mkdir("output") unless Dir.exists?("output")

    filename = "output/thanks_#{id}.html"

    File.open(filename,'w') do |file|
        file.puts form_letter
    end
end

def files_existing(array_of_filenames)
    array_of_filenames.all? { |filename| File.exist? filename }
end


puts "EventManager Initialized!"

file_name_template_letter = "form_letter.html"
file_name_event_attendees = "event_attendees.csv"

all_files = [file_name_template_letter, file_name_event_attendees]

if(files_existing(all_files))
    template_letter = File.read file_name_template_letter

    contents = CSV.open file_name_event_attendees, headers: true, header_converters: :symbol

    template_letter = File.read "form_letter.erb"
    erb_template = ERB.new template_letter

    regdates = []

    contents.each do |row|
        id = row[0]
        name = row[:first_name]
        zipcode = clean_zipcode(row[:zipcode])
        legislators = legislators_by_zipcode(zipcode)

        homephone = clean_phone_number(row[:homephone])

        regdates.concat([row[:regdate]])

        form_letter = erb_template.result(binding)

        save_thank_you_letter(id,form_letter)
    end
    prime_hour = prime_reg_hour(regdates)
    prime_day = prime_reg_day(regdates)

    puts "The hour which most people are registered is #{prime_hour}, and the weekday is #{prime_day}."
else
    puts "Could not find files"
end