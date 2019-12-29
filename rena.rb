#
# This source code is under the Unlicense
#
module Rena
    class Rena
        def initialize(ignore = nil, keys = nil)
            @ignoreOrg = wrap(ignore)
            if ignore then
                @ignore = lambda do |match, index, attr|
                    matched, indexNew, attrNew = @ignoreOrg.call(match, index, attr)
                    if matched.nil? then
                        index
                    else
                        indexNew
                    end
                end
            else
                @ignore = lambda do |match, index, attr| index end
            end
            @keys = keys
        end

        def isEnd()
            lambda do |match, index, attr|
                if index >= match.length then
                    ["", index, attr]
                else
                    [nil, nil, nil]
                end
            end
        end

        def concat(*exps)
            concatSkip(@ignore, *exps)
        end

        def choice(*exps)
            lambda do |match, index, attr|
                exps.each do |exp|
                    matched, indexNew, attrNew = wrap(exp).call(match, index, attr)
                    if !matched.nil? then
                        return [matched, indexNew, attrNew]
                    end
                end
                [nil, nil, nil]
            end
        end

        def action(exp, action)
            wrapped = wrap(exp)
            lambda do |match, index, attr|
                matched, indexNew, attrNew = wrapped.call(match, index, attr)
                if matched.nil? then
                    [nil, nil, nil]
                else
                    [matched, indexNew, action.call(matched, attrNew, attr)]
                end
            end
        end

        def lookaheadNot(exp)
            wrapped = wrap(exp)
            lambda do |match, index, attr|
                matched, indexNew, attrNew = wrapped.call(match, index, attr)
                if matched.nil? then
                    ["", index, attr]
                else
                    [nil, nil, nil]
                end
            end
        end

        def letrec(*funcs)
            fg = lambda do |g| g.call(g) end
            fp = lambda do |p|
                res = []
                funcs.each do |func|
                    (lambda do |func|
                        res.push(lambda do |match, index, attr|
                            (func.call(*(p.call(p)))).call(match, index, attr)
                        end)
                    end).call(func)
                end
                res
            end
            (fg.call(fp))[0]
        end

        def zeroOrMore(exp)
            wrapped = wrap(exp)
            letrec(lambda do |y| choice(concat(wrapped, y), "") end)
        end

        def oneOrMore(exp)
            concat(exp, zeroOrMore(exp))
        end

        def opt(exp)
            choice(exp, "")
        end

        def lookahead(exp)
            lookaheadNot(lookaheadNot(exp))
        end

        def attr(val)
            action("", lambda do |match, index, attr| val end)
        end

        def real()
            action(
                /[\+\-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)(?:[eE][\+\-]?[0-9]+)?/,
                lambda do |match, index, attr| match.to_f end)
        end

        def key(key)
            skipKeys = []
            if @keys.nil? then
                raise "Keys are not set"
            end
            @keys.each do |optKey|
                if key.length < optKey.length and key == optKey[0, key.length] then
                    skipKeys.push(optKey)
                end
            end
            concat(lookaheadNot(choice(*skipKeys)), key)
        end

        def notKey()
            if @keys.nil? then
                raise "Keys are not set"
            end
            lookaheadNot(choice(*@keys))
        end

        def equalsId(key)
            notSkip = lambda do |match, index, attr| index end
            if not @ignoreOrg and not @keys then
                wrap(key)
            elsif @ignoreOrg and not @keys then
                concatSkip(notSkip, key, choice(isEnd(), lookahead(@ignoreOrg)))
            elsif not @ignoreOrg and @keys then
                concatSkip(notSkip, key, choice(isEnd(), lookaheadNot(notKey())))
            else
                concatSkip(notSkip, key, choice(isEnd(), lookahead(@ignoreOrg), lookaheadNot(notKey())))
            end
        end

        private
        def wrap(pattern)
            if pattern.is_a?(String) then
                lambda do |str, index, attr| 
                    if str[index, str.length].start_with?(pattern) then
                        [pattern, index + pattern.length, attr]
                    else
                        [nil, nil, nil]
                    end
                end
            elsif pattern.is_a?(Regexp) then
                lambda do |str, index, attr| 
                    result = str.match(pattern, index)
                    if result.nil? || result.begin(0) > index then
                        [nil, nil, nil]
                    else
                        [result[0], index + result[0].length, attr]
                    end
                end
            else
                pattern
            end
        end

        def concatSkip(skipSpace, *exps)
            lambda do |match, index, attr|
                indexNew = index
                attrNew = attr
                exps.each do |exp|
                    matched, indexNew, attrNew = wrap(exp).call(match, indexNew, attrNew)
                    if matched.nil? then
                        return [nil, nil, nil]
                    else
                        indexNew = skipSpace.call(match, indexNew, attrNew)
                    end
                end
                [match[index, indexNew - index], indexNew, attrNew]
            end
        end
    end
end

