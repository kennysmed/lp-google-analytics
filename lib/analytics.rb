# coding: utf-8
require 'legato'

# Use one of these classes something like this:
#
# UniqueVisitorByDate.results(user.profiles.first,
#                     :start_date => (Date.today - 8),
#                     :end_date => (Date.today - 1),
#                     :sort => ['date']
#                   ).each { |result| p result }
#
#<OpenStruct date="20130417", visitors="411">
#<OpenStruct date="20130418", visitors="436">
#<OpenStruct date="20130419", visitors="374">
#<OpenStruct date="20130420", visitors="279">
#<OpenStruct date="20130421", visitors="328">
#<OpenStruct date="20130422", visitors="448">
#<OpenStruct date="20130423", visitors="429">
#<OpenStruct date="20130424", visitors="412">

class PageviewByDate
  extend Legato::Model
  metrics :pageviews
  dimensions :date
end

class PageviewByWeek
  extend Legato::Model
  metrics :pageviews
  dimensions :week
end

class VisitorByHour
  extend Legato::Model
  metrics :visitors # Actually, unique visitors.
  dimensions :date, :hour
end

class VisitorByDate
  extend Legato::Model
  metrics :visitors # Actually, unique visitors.
  dimensions :date
end

class VisitorByWeek
  extend Legato::Model
  metrics :visitors # Actually, unique visitors.
  dimensions :week
end


class VisitByHour
  extend Legato::Model
  metrics :visits
  dimensions :date, :hour
end

class VisitByDate
  extend Legato::Model
  metrics :visits
  dimensions :date
end

class VisitByWeek
  extend Legato::Model
  metrics :visits
  dimensions :week
end
