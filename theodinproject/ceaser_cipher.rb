#! /usr/bin/env ruby

require 'optparse'

# A simple implementation of the Caesar cipher in Ruby.
# This script takes a string and a shift value, and returns the encrypted string using right shift.
# Usage: caesar_cipher("What a string!", 5)
# Output: "Bmfy f xywnsl!"

CIPHER_HASH = {
  :a => 0,
  :b => 1,
  :c => 2,
  :d => 3,
  :e => 4,
  :f => 5,
  :g => 6,
  :h => 7,
  :i => 8,
  :j => 9,
  :k => 10,
  :l => 11,
  :m => 12,
  :n => 13,
  :o => 14,
  :p => 15,
  :q => 16,
  :r => 17,
  :s => 18,
  :t => 19,
  :u => 20,
  :v => 21,
  :w => 22,
  :x => 23,
  :y => 24,
  :z => 25
}

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: caesar_cipher.rb [options]"

  opts.on("-s", "--string STRING", "The string to be encrypted") do |s|
    options[:string] = s
  end

  opts.on("-n", "--shift SHIFT", "The shift value for the cipher, use negative values for decryption") do |n|
    options[:shift] = n.to_i
  end

end.parse!


# Convert the string to a list of numbers based on the CIPHER_HASH
def convert_to_number(string)
  hash_list = []
  string.chars.each do |char|
    if char.match?(/[a-zA-Z]/)
      hash_list << CIPHER_HASH[char.downcase.to_sym]
    else
      hash_list << char
    end
  end
  return hash_list
end

hash_list = convert_to_number(options[:string])


# Shift the numbers in the list by the specified shift value, wrapping around using modulo 26
# If the element is not a number (i.e., it's a non-alphabetic character), it should be left unchanged
def shift_number(hash_list, shift)
  shifted_list = []
  hash_list.each do |number|
    if !number.is_a?(Integer)
      shifted_list << number
    else
      shifted_number = (number + shift) % 26
      shifted_list << shifted_number
    end
  end
  return shifted_list
end

shifted_list = shift_number(hash_list, options[:shift])

# Convert the shifted numbers back to characters using the CIPHER_HASH
# If the element is not a number, it should be left unchanged
def convert_to_string(shifted_list)
  string = ""
  shifted_list.each do |number|
    if !number.is_a?(Integer)
      string += number
    else
      char = CIPHER_HASH.key(number).to_s
      string += char
    end
  end
  return string
end

encrypted_string = convert_to_string(shifted_list)

def match_case(original_string, encrypted_string)
  result = ""
  original_string.chars.each_with_index do |char, index|
    if char.match?(/[a-zA-Z]/)
      if char.upcase == char
        result += encrypted_string[index].upcase
      else
        result += encrypted_string[index].downcase
      end
    else
      result += char
    end
  end
  return result
end

final_string = match_case(options[:string], encrypted_string)
puts "#{final_string}"
