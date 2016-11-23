require './fv.rb'

input_matr = [
  [2, 4 ,3],
  [1, 8, 5],
  [7, 0, 6]
]

output_matr = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 0]
]

kg = 1
kh = 1

FV.configure do |config|
  config.input = input_matr
  config.output = output_matr
  config.kg = 1
  config.kh = 1
end

calc = FV::Calculation.new
calc.call
puts calc.min_steps

# fv = FV.new(input: input_matr, output: output_matr, kg: kg, kh: kh)

# fv = 

# fv.call

# puts fv.min_steps
