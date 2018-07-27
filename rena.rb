#
# rena-ruby
#
# Copyright (c) 2018 Yuichiro MORIGUCHI
#
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
#
module Rena
	def Rena(ignore = nil)
		RenaFactory.new(ignore)
	end

	class RenaFactory
		def initialize(ignore)
			@ignore = ignore
		end

		def find(pattern)
			RenaInstance.new(self).find(pattern)
		end

		def alt(*alternation)
			RenaInstance.new(self).alt(*alternation)
		end

		def times(countmin, countmax, pattern, action = nil, init = nil)
			RenaInstance.new(self).findTimes(countmin, countmax, pattern, action, init)
		end

		def atLeast(count, pattern, action = nil, init = nil)
			RenaInstance.new(self).findAtLeast(count, pattern, action, init)
		end

		def atMost(count, pattern, action = nil, init = nil)
			RenaInstance.new(self).findAtMost(count, pattern, action, init)
		end

		def maybe(pattern, action = nil, init = nil)
			RenaInstance.new(self).findMaybe(pattern, action, init)
		end

		def zeroOrMore(pattern, action = nil, init = nil)
			RenaInstance.new(self).findZeroOrMore(pattern, action, init)
		end

		def oneOrMore(pattern, action = nil, init = nil)
			RenaInstance.new(self).findOneOrMore(pattern, action, init)
		end

		def delimit(pattern, delimiter, action, init)
			RenaInstance.new(self).findDelimit(pattern, delimiter, action, init)
		end

		attr_reader :ignore
	end

	class RenaInstance
		def initialize(factory)
			@factory = factory
			@patterns = []
		end

		def find(pattern, action = nil)
			@patterns.push(lambda do |str, index, attribute|
				strnew, indexnew, attributenew = wrap(pattern).call(str, index, attribute)
				[strnew, indexnew, wrapAction(action).call(strnew, attributenew, attribute)]
			end)
			self
		end

		def +(pattern)
			find(pattern)
		end

		def alt(*alternation)
			@patterns.push(lambda do |str, index, attribute|
				alternation.each do |pattern|
					result = wrap(pattern).call(str, index, attribute)
					if !result.nil? then
						return result
					end
				end
				nil
			end)
			self
		end

		def |(pattern)
			@factory.alt(self, pattern)
		end

		def times(countmin, countmax, action = nil, init = nil)
			@factory.times(countmin, countmax, self, action, init)
		end

		def atLeast(count, action = nil, init = nil)
			@factory.atLeast(count, self, action, init)
		end

		def atMost(count, action = nil, init = nil)
			@factory.atMost(count, self, action, init)
		end

		def maybe(action = nil, init = nil)
			@factory.maybe(self, action, init)
		end

		def zeroOrMore(action = nil, init = nil)
			@factory.zeroOrMore(self, action, init)
		end

		def oneOrMore(action = nil, init = nil)
			@factory.oneOrMore(self, action, init)
		end

		def delimit(delimiter, action = nil, init = nil)
			@factory.delimit(self, delimiter, action, init)
		end

		def findTimes(countmin, countmax, pattern, action, init)
			@patterns.push(lambda do |str, index, attribute|
				wrappedPtn = wrap(pattern)
				wrappedAction = wrapAction(action)
				count = 0
				indexnew = index
				inherited = if init.nil? then attribute else init end
				while countmax < 0 || count < countmax
					result = wrappedPtn.call(str, indexnew, inherited)
					if result.nil? then
						break
					end
					strnew, indexnew, attributenew = result
					inherited = wrappedAction.call(strnew, attributenew, inherited)
					indexnew = skipSpace(str, indexnew)
					count += 1
				end
				if count < countmin then nil else [str, indexnew, inherited] end
			end)
			self
		end

		def findAtLeast(count, pattern, action = nil, init = nil)
			findTimes(count, -1, pattern, action, init)
		end

		def findAtMost(count, pattern, action = nil, init = nil)
			findTimes(0, count, pattern, action, init)
		end

		def findMaybe(pattern, action = nil)
			findTimes(0, 1, pattern, action, nil)
		end

		def findZeroOrMore(pattern, action = nil, init = nil)
			findTimes(0, -1, pattern, action, init)
		end

		def findOneOrMore(pattern, action = nil, init = nil)
			findTimes(1, -1, pattern, action, init)
		end

		def findDelimit(pattern, delimiter, action, init)
			@patterns.push(lambda do |str, index, attribute|
				wrappedPtn = wrap(pattern)
				wrappedDelimit = wrap(delimiter)
				wrappedAction = wrapAction(action)
				inherited = if init.nil? then attribute else init end

				result = wrappedPtn.call(str, index, inherited)
				if result.nil? then
					return nil
				end
				strnew, indexnew, attributenew = result
				inherited = wrappedAction.call(strnew, attributenew, inherited)
				indexnew = skipSpace(str, indexnew)
				loop do
					resultDelimit = wrappedDelimit.call(str, indexnew, inherited)
					if resultDelimit.nil? then
						return [str, indexnew, inherited]
					end
					strnew, indexnew, attributenew = resultDelimit
					indexnew = skipSpace(str, indexnew)
					result = wrappedPtn.call(str, indexnew, inherited)
					if result.nil? then
						return nil
					end
					strnew, indexnew, attributenew = result
					inherited = wrappedAction.call(strnew, attributenew, inherited)
					indexnew = skipSpace(str, indexnew)
				end
			end)
			self
		end

		def match(str, index = 0, attribute = nil)
			strres, indexnew, attributenew = "", index, attribute
			@patterns.each do |pattern|
				strnew, indexnew, attributenew = pattern.call(str, indexnew, attributenew)
				if strnew.nil?
					return nil
				end
				strres += strnew
			end
			[strres, indexnew, attributenew]
		end

		def lookahead(pattern, positive = true)
			@patterns.push(lambda do |str, index, attribute|
				strnew, indexnew, attributenew = wrap(pattern).call(str, index, attribute)
				if strnew.nil? != positive then ["", index, attribute] else nil end
			end)
			self
		end

		def lookaheadNot(pattern, positive)
			lookahead(pattern, false)
		end

		def cond(condition)
			@patterns.push(lambda do |str, index, attribute|
				if condition.call(attribute) then ["", index, attribute] else nil end
			end)
			self
		end

		def attribute(attribute)
			@patterns.push(lambda { |str, index, ignored| ["", index, attribute] })
			self
		end

		def action(action)
			@patterns.push(lambda { |str, index, ignored| ["", index, action.call(attribute)] })
			self
		end

		private
		def wrap(pattern)
			if pattern.is_a?(String) then
				lambda do |str, index, attribute| 
					if str[index, str.length].start_with?(pattern) then
						[pattern, index + pattern.length, nil]
					else
						nil
					end
				end
			elsif pattern.is_a?(Regexp) then
				lambda do |str, index, attribute| 
					result = str.match(pattern, index)
					if result.nil? || result.begin(0) != index then
						nil
					else
						[result[0], index + result[0].length, nil]
					end
				end
			elsif pattern.is_a?(RenaInstance) then
				lambda {|str, index, attribute| pattern.match(str, index, attribute) }
			else
				pattern
			end
		end

		def wrapAction(action)
			if action.nil? then
				lambda {|match, attribute, inherited| attribute}
			else
				action
			end
		end

		def skipSpace(str, index)
			if !@factory.ignore.nil? then
				ignore1, indexnew, ignore3 = @factory.ignore.call(str, index, nil)
				indexnew
			else
				index
			end
		end
	end
end
