#
# This source code is under the Unlicense
#
require 'minitest/unit'
require 'minitest/autorun'
require './rena.rb'

class TestRena < MiniTest::Unit::TestCase
    def setup
        @r = Rena::Rena.new()
        @r01 = Rena::Rena.new(/[\s]+/)
        @r02 = Rena::Rena.new(nil, ["+", "+=", "++", "-"])
        @r03 = Rena::Rena.new(/[\s]+/, ["+", "+=", "++", "-"])
    end

    def teardown
    end

    def match(exp, toMatch, expectedMatch, expectedIndex)
        matched, index, attr = exp.call(toMatch, 0, 0)
        assert_equal expectedMatch, matched
        assert_equal expectedIndex, index
    end

    def matchAttr(exp, toMatch, initAttr, expectedMatch, expectedIndex, expectedAttr)
        matched, index, attr = exp.call(toMatch, 0, initAttr)
        assert_equal expectedMatch, matched
        assert_equal expectedIndex, index
        assert_equal expectedAttr, attr
    end

    def nomatch(exp, toMatch)
        matched, index, attr = exp.call(toMatch, 0, 0)
        assert_nil matched
    end

    def test_simple
        a = @r.concat("765")
        match(a, "765pro", "765", 3)
        nomatch(a, "961pro")
        nomatch(a, "")
    end

    def test_regex
        a = @r.concat(/[a-z]{3}/)
        match(a, "abd", "abd", 3)
        match(a, "xyz", "xyz", 3)
        nomatch(a, "961")
        nomatch(a, "")
    end

    def test_isend
        a = @r.isEnd()
        match(a, "", "", 0)
        nomatch(a, "961")
    end

    def test_concat
        a = @r.concat("765", "pro")
        match(a, "765pro", "765pro", 6)
        nomatch(a, "961pro")
        nomatch(a, "765aaa")
        nomatch(a, "765")
    end

    def test_choice
        a = @r.choice("765", "346", "283")
        match(a, "765", "765", 3)
        match(a, "346", "346", 3)
        match(a, "283", "283", 3)
        nomatch(a, "961")
    end

    def test_zeroOrMore
        a = @r.zeroOrMore(/[a-z]/)
        match(a, "abd", "abd", 3)
        match(a, "", "", 0)
    end

    def test_lookahead
        a = @r.lookahead("765")
        match(a, "765", "", 0)
        nomatch(a, "346")
        nomatch(a, "961")
    end

    def test_lookaheadNot
        a = @r.lookaheadNot("961")
        match(a, "765", "", 0)
        match(a, "346", "", 0)
        nomatch(a, "961")
    end

    def test_action
        a = @r.action(@r.concat(/[0-9]{3}/), lambda do |match, syn, inh| match.to_i + inh end)
        matchAttr(a, "765", 346, "765", 3, 1111)
        nomatch(a, "abd")
    end

    def test_letrec
        a = @r.letrec(lambda do |a| @r.choice(@r.concat("(", a, ")"), "") end)
        match(a, "((())))", "((()))", 6)
        match(a, "((())", "", 0)
    end

    def test_oneOrMore
        a = @r.oneOrMore(/[a-z]/)
        match(a, "abd", "abd", 3)
        match(a, "a", "a", 1)
        nomatch(a, "")
    end

    def test_opt
        a = @r.opt("765")
        match(a, "765", "765", 3)
        match(a, "961", "", 0)
    end

    def test_attr
        a = @r.attr(27)
        matchAttr(a, "aaa", 0, "", 0, 27)
    end

    def test_real
        a = @r.real()
        def assertReal(str, num)
            matched, index, attr = @r.real().call(str, 0, 0)
            assert_equal num, attr
        end
        assertReal("765", 765);
        assertReal("76.5", 76.5);
        assertReal("0.765", 0.765);
        assertReal(".765", 0.765);
        assertReal("765e2", 76500);
        assertReal("765E2", 76500);
        assertReal("765e+2", 76500);
        assertReal("765e-2", 7.65);
        #assertReal("765e+346", Infinity);
        assertReal("765e-346", 0);
        nomatch(a, "a961");
        assertReal("+765", 765);
        assertReal("+76.5", 76.5);
        assertReal("+0.765", 0.765);
        assertReal("+.765", 0.765);
        assertReal("+765e2", 76500);
        assertReal("+765E2", 76500);
        assertReal("+765e+2", 76500);
        assertReal("+765e-2", 7.65);
        #assertReal("+765e+346", Infinity);
        assertReal("+765e-346", 0);
        nomatch(a, "+a961");
        assertReal("-765", -765);
        assertReal("-76.5", -76.5);
        assertReal("-0.765", -0.765);
        assertReal("-.765", -0.765);
        assertReal("-765e2", -76500);
        assertReal("-765E2", -76500);
        assertReal("-765e+2", -76500);
        assertReal("-765e-2", -7.65);
        #assertReal("-765e+346", -Infinity);
        assertReal("-765e-346", 0);
        nomatch(a, "-a961");
    end

    def test_key
        a = @r02.key("+")
        match(a, "+!", "+", 1)
        nomatch(a, "+=")
        nomatch(a, "++")
        nomatch(a, "-")
    end

    def test_notKey
        a = @r02.notKey()
        match(a, "!", "", 0)
        nomatch(a, "+")
        nomatch(a, "+=")
        nomatch(a, "++")
        nomatch(a, "-")
    end

    def test_equalsId1
        a = @r.equalsId("key")
        match(a, "key", "key", 3)
        match(a, "keys", "key", 3)
        match(a, "key+", "key", 3)
        match(a, "key ", "key", 3)
    end

    def test_equalsId2
        a = @r01.equalsId("key")
        match(a, "key", "key", 3)
        nomatch(a, "keys")
        nomatch(a, "key+")
        match(a, "key ", "key", 3)
    end

    def test_equalsId3
        a = @r02.equalsId("key")
        match(a, "key", "key", 3)
        nomatch(a, "keys")
        match(a, "key+", "key", 3)
        nomatch(a, "key ")
    end

    def test_equalsId4
        a = @r03.equalsId("key")
        match(a, "key", "key", 3)
        nomatch(a, "keys")
        match(a, "key+", "key", 3)
        match(a, "key ", "key", 3)
    end

    def test_skipSpace1
        a = @r03.concat("765", "pro")
        match(a, "765  pro", "765  pro", 8)
        match(a, "765pro", "765pro", 6)
        nomatch(a, "765  aaa")
    end

    def test_skipSpace2
        a = @r03.zeroOrMore(/[a-z]/)
        match(a, "a  b d", "a  b d", 6)
        match(a, "abd", "abd", 3)
        match(a, "961", "", 0)
    end
end
