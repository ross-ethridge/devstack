#! /usr/bin/env ruby

def substrings(string, dictionary)
  result = Hash.new(0)
  string.downcase!
  dictionary.each do |word|
    word.downcase!
    result[word] += 1 if string.include?(word)
  end
  result
end

puts "Create a dictionary of words (separated by commas):"
dictionary = gets.chomp.split(", ")

puts "Enter the substrings to search for as a string :"
string = gets.chomp

result = substrings(string, dictionary)
puts "Substrings found in the string:"
result.each do |word, count|
  puts "#{word}: #{count}"
end


# Example usage:
# ./substrings.rb
# Create a dictionary of words (separated by commas):
# cow, moon, jump, cat
# Enter the substrings to search for as a string :
# "hey diddle diddle the cat and the fiddle the cow jumped over the moon"
# Substrings found in the string:
# cow: 1
# moon: 1
# jump: 1
# cat: 1
# The output will show the count of each word from the dictionary that is found in the input string.
