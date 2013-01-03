module Rly

	class Lex
		def self.ignore_spaces_and_tabs
			ignore " \t"
		end

		def self.lex_number_tokens
			token :NUMBER, /\d+/ do |t|
				t.value = t.value.to_i
				t
			end
		end

		def self.lex_double_quoted_string_tokens
			token :STRING, /"[^"]*"/ do |t|
				t.value = t.value[1...-1]
				t
			end
		end
	end

	class Yacc
		def self.with_values
			raise ArgumentError.new("Must pass a block") unless block_given?
			->(*args) {
				ret = args.shift
				ret.value = yield *args.map { |a| a.value }
			}
		end

		def self.assign_rhs(idx=1)
			->(*args) {
				ret = args.shift
				idx -= 1
				ret.value = args[idx] ? args[idx].value : nil
			}
		end

		def self.collect_to_a
			->(ret, val, *args) {
				ret.value = [val.value]
				vals = args[-1]
				ret.value += vals.value if vals
			}
		end
	end

end