#!/usr/bin/env ruby
require 'terminal-table'

table = Terminal::Table.new do |t|
  t << [1, 2, 33, 4]
  t << [12345, {:value => 54321, :colspan => 2}, '']
  t << [{:value => 123456789, :colspan => 2}, 4, '']
  t << [{:value => 123, :colspan => 2}, {:value => 444444444, :colspan => 2}]
  t << [{:value => 0, :colspan => 3}, '']
=begin
DP Process:
    Note: pad = 3 = 1 + 1 + 1 (pad_right + pad_left + border_y.length)
-------
    0~0: [
            1, # =  1.to_s.length
            5, # =  12345.to_s.length
         ].max = 5
    1~1: [
            1, # =  2.to_s.length
         ].max = 1
    2~2: [
            2, # =  33.to_s.length
            1, # =  4.to_s.length
         ].max = 2
    3~3: [
            1, # =  4.to_s.length
            0, # =  ''.length
            0, # =  ''.length
            0, # =  ''.length
         ].max = 1
-------
    0~1: [
            9, # =  1 +  5 + 3 (0~0 + 1~1 + pad)
            9, # =  123456789.to_s.length
            3, # =  123.to_s.length
         ].max = 9
    1~2: [
            6, # =  1 +  2 + 3 (1~1 + 2~2 + pad)
            5, # =  54321.to_s.length
         ].max = 6
    2~3: [
            6, # =  2 +  1 + 3 (2~2 + 3~3 + pad)
            9, # =  444444444.to_s.length
         ].max = 9
-------
    0~2: [
           14, # =  5 +  6 + 3 (0~0 + 1~2 + pad)
           14, # =  9 +  2 + 3 (0~1 + 2~2 + pad)
            1, # =  0.to_s.length
         ].max = 14
    1~3: [
           13, # =  1 +  9 + 3 (1~1 + 2~3 + pad)
           10, # =  6 +  1 + 3 (1~2 + 3~3 + pad)
         ].max = 13
-------
    0~3: [
           21, # =  5 + 13 + 3 (0~0 + 1~3 + pad)
           21, # =  9 +  9 + 3 (0~1 + 2~3 + pad)
           18, # = 14 +  1 + 3 (0~2 + 3~3 + pad)
         ].max = 21
=======
Resolve:

0~3: 21
  dividable: true
  0~0: 5
  1~3: 13
    dividable: true
    1~1: 1
    2~3: 9
      dividable: false
      # choose second best result
      rem: 3 = 9 - 2 - 1 - 3 (2~3 - 2~2 - 3~3 - pad)
      # since 2 > 1 (2~2 > 3~3), 2~2 got the remainder
      2~2: 4 = 2 + 3/2 + 3%2 (3~3 + rem/2 + rem%2)
      3~3: 2 = 1 + 3/2       (2~2 + rem/2)

@column_widths=[5, 1, 4, 2]
========
Output
+-------+---+------+----+
| 1     | 2 | 33   | 4  |
| 12345 | 54321    |    |
| 123456789 | 4    |    |
| 123       | 444444444 |
| 0                |    |
+-------+---+------+----+
  -----   -------------   <- first resolve
          -   ---------   <- second resolve
              --/%   -/   <- third resolve with remainder
=end
end
puts table

table = Terminal::Table.new do |t|
  t << [1, {:value => 2222222, :colspan => 2}]
  t << [{:value => 33333, :colspan => 2}, 444]
=begin
DP Process:
    Note: pad = 3 = 1 + 1 + 1 (pad_right + pad_left + border_y.length)
-------
    0~0: [
            1, # =  1.to_s.length
         ].max = 1
    1~1: [
            1, # default!
         ].max = 1
    2~2: [
            3, # =  444.to_s.length
         ].max = 3
-------
    0~1: [
            5, # =  1 +  1 + 3 (0~0 + 1~1 + pad)
            5, # =  33333.to_s.length
         ].max = 5
    1~2: [
            7, # =  1 +  3 + 3 (1~1 + 2~2 + pad)
            7, # =  2222222.to_s.length
         ].max = 7
-------
    0~2: [
           11, # =  1 +  7 + 3 (0~0 + 1~2 + pad)
           11, # =  5 +  3 + 3 (0~1 + 2~2 + pad)
         ].max = 11
=======
Resolve:

0~2: 11
  dividable: true
  0~0: 1
  1~2: 7
    dividable: true
      FIXME: broken

@column_widths=[1, 1, 3]
========
Output
FIXME: make an ugly case
FIXME: how to handle this????????
+---+-+-----+
| 1 | 22222 |
| 333 | 444 |
+---+-+-----+
+---+---+-----+
| 1 | 22222   |
| 333   | 444 |
+---+---+-----+
  -   -----
        ---

FIXME: this?
+---++-----+
| 1 | 2222 |
| 33 | 444 |
+---++-----+
+---+---+-----+
| 1 | 2222    |
| 33    | 444 |
+---+---+-----+
=end
end
puts table

table = Terminal::Table.new do |t|
  t << [1, 2, 3]
  t << [4, {:value => 5555555, :colspan => 2}]
  t << [{:value => 66666666 , :colspan => 2}, 777]
  t << [{:value => 20202020202020202020, :colspan => 3}]
=begin
DP Process:
    Note: pad = 3 = 1 + 1 + 1 (pad_right + pad_left + border_y.length)
-------
    0~0: [
            1, # =  1.to_s.length
         ].max = 1
    1~1: [
            1, # =  2.to_s.length
         ].max = 1
    2~2: [
            1, # =  3.to_s.length
         ].max = 1
-------
    0~1: [
            5, # =  1 +  1 + 3 (0~0 + 1~1 + pad)
         ].max = 5
    1~2: [
            5, # =  1 +  1 + 3 (1~1 + 2~2 + pad)
         ].max = 5
-------
    0~2: [
            9, # =  5 +  1 + 3 (0~1 + 2~2 + pad)
            9, # =  5 +  1 + 3 (0~0 + 1~2 + pad)
           20, # =  20202020202020202020.to_s.length
         ].max = 20
=======
Resolve:

FIXME: make it evenly distributed?

@column_widths=[4, 3, 7]
========
Output
+------+-----+---------+
| 1    | 2   | 3       |
| 20202020202020202020 |
+------+-----+---------+
  -----/////   -/////%
  -//%   -//
=end
end
puts table
