# coding: utf-8
require 'legato'

# Use one of these classes something like this:
#
# UniqueVisitor.dimensions(:date, :hour)
# UniqueVisitor.results(user.profiles.first,
#                     :start_date => (Date.today - 8),
#                     :end_date => (Date.today - 1),
#                     :sort => ['date', 'hour']
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

class UniqueVisitor
    extend Legato::Model
    metrics :visitors # Actually, unique visitors.
end

class Visit
    extend Legato::Model
    metrics :visits
end
