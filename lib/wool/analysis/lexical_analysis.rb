module Wool
  # This is a set of methods that get provided to Warnings so they can perform
  # lexical analysis of their bodies. This module handles tokenizing only - not
  # parse-trees.
  module LexicalAnalysis
    class Token < Struct.new(:type, :body, :line, :col)
      
    end
    
    # Lexes the given text.
    #
    # @param [String] body (self.body) The text to lex
    # @return [Array<Array<Integer, Integer>, Symbol, String>] A set of tokens
    #   in Ripper's result format. Each token is an array of the form:
    #   [[1, token_position], token_type, token_text]. I'm not exactly clear on
    #   why the 1 is always there. At any rate - the result is an array of those
    #   tokens.
    def lex(body = self.body)
      Ripper.lex(body)
    end

    # Returns the text between two token positions. The token positions are
    # in [line, column] format. The body, left, and right tokens must be provided,
    # and optionally, you can override the inclusiveness of the text-between operation.
    # It defaults to :none, for including neither the left nor right tokens in the
    # result. You can pass :none, :left, :right, or :both.
    #
    # @param [String] body (self.body) The first parameter is optional: the text
    #   to search. This defaults to the full text.
    # @param [Token] left the left token to get the text between
    # @param [Token] right the right token to get the text between
    # @param [Symbol] inclusive should the :left, :right, :both, or :none tokens
    #    be included in the resulting text?
    # @return the text between the two tokens within the text. This is necessary
    #    because the lexer provides [line, column] coordinates which is quite
    #    unfortunate.
    def text_between_token_positions(text, left, right, inclusive = :none)
      result = ""
      lines = text.lines.to_a
      left[0][0].upto(right[0][0]) do |cur_line|
        line = lines[cur_line - 1]
        result << left[2] if cur_line == left[0][0] && (inclusive == :both || inclusive == :left)
        left_bound = cur_line == left[0][0] ? left[0][1] + left[2].size : 0
        right_bound = cur_line == right[0][0] ? right[0][1] - 1 : -1
        result << line[left_bound..right_bound]
        result << right[2] if cur_line == right[0][0] && (inclusive == :both || inclusive == :right)
      end
      result
    end
      
    # Searches for the given token using standard [body], target symbols syntax.
    # Yields for each token found that matches the query, and returns all those
    # who match.
    #
    # @param [String] body (self.body) The first parameter is optional: the text
    #   to search. This defaults to the full text.
    # @param [Symbol] token The rest of the arguments are tokens to search
    #   for. Any number of tokens may be specified.
    # @return [Array<Array>] All the matching tokens for the query
    def select_token(*args)
      body, list = _extract_token_search_args(args)
      result = []
      while (token = find_token(body, *list)) && token != nil
        result << token if yield(*token)
        _, body = split_on_token(body, *list)
        body = body[token[2].size..-1]
      end
      return result
    end
    
    # Finds the first instance of a set of keywords in the body. If no text is
    # given to scan, then the full content is scanned.
    #
    # @param [String] body (self.body) The first parameter is optional: the text
    #   to search. This defaults to the full text.
    # @param [Symbol] keyword The rest of the arguments are keywords to search
    #   for. Any number of keywords may be specified.
    # @return [Array] the token in the form returned by Ripper. See #lex.
    def find_keyword(*args)
      body, list = _extract_token_search_args(args)
      list.map! {|x| x.to_s}
      lexed = lex(body)
      lexed.find.with_index do |tok, idx|
        is_keyword = tok[1] == :on_kw && list.include?(tok[2])
        is_not_symbol = idx == 0 || lexed[idx-1][1] != :on_symbeg
        is_keyword && is_not_symbol
      end
    end

    # Finds the first instance of a set of tokens in the body. If no text is
    # given to scan, then the full content is scanned.
    #
    # @param [String] body (self.body) The first parameter is optional: the text
    #   to search. This defaults to the full text.
    # @param [Symbol] token The rest of the arguments are tokens to search
    #   for. Any number of tokens may be specified.
    # @return [Array] the token in the form returned by Ripper. See #lex.
    def find_token(*args)
      body, list = _extract_token_search_args(args)
      lexed = lex(body)
      lexed.find.with_index do |tok, idx|
        is_token = list.include?(tok[1])
        is_not_symbol = idx == 0 || lexed[idx-1][1] != :on_symbeg
        is_token && is_not_symbol
      end
    end

    # Splits the body into two halfs based on the first appearance of a keyword.
    #
    # @example
    #   split_on_keyword('x = 5 unless y == 2', :unless)
    #   # => ['x = 5 ', 'unless y == 2']
    # @param [String] body (self.body) The first parameter is optional: the text
    #   to search. This defaults to the full text.
    # @param [Symbol] token The rest of the arguments are keywords to search
    #   for. Any number of keywords may be specified.
    # @return [Array<String, String>] The body split by the keyword.
    def split_on_keyword(*args)
      body, keywords = _extract_token_search_args(args)
      token = find_keyword(body, *keywords)
      return _split_body_with_raw_token(body, token)
    end

    # Splits the body into two halfs based on the first appearance of a token.
    #
    # @example
    #   split_on_token('x = 5 unless y == 2', :on_kw)
    #   # => ['x = 5 ', 'unless y == 2']
    # @param [String] body (self.body) The first parameter is optional: the text
    #   to search. This defaults to the full text.
    # @param [Symbol] token The rest of the arguments are tokens to search
    #   for. Any number of tokens may be specified.
    # @return [Array<String, String>] The body split by the token.
    def split_on_token(*args)
      body, tokens = _extract_token_search_args(args)
      token = find_token(body, *tokens)
      return _split_body_with_raw_token(body, token)
    end

    private

    def _extract_token_search_args(args)
      if args.first.is_a?(String)
        return args[0], args[1..-1]
      else
        return self.body, args
      end
    end

    def _split_body_with_raw_token(body, token)
      max = token ? [0, token[0][1]].max : body.size
      return body[0,max], body[max..-1]
    end
  end
end