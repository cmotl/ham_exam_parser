# frozen_string_literal: true

module HamExamParser
  class Question
    attr_accessor :id, :subelement, :group, :question, :answers,
                  :correct_answer, :reference, :figure,
                  :figure_image_base64

    def initialize(attrs = {})
      @id = attrs[:id]
      @subelement = attrs[:subelement]
      @group = attrs[:group]
      @question = attrs[:question]
      @answers = attrs[:answers] || {}
      @correct_answer = attrs[:correct_answer]
      @reference = attrs[:reference]
      @figure = attrs[:figure]
      @figure_image_base64 = attrs[:figure_image_base64]
    end

    def to_h
      {
        id: @id,
        question: @question,
        answers: @answers,
        correct_answer: @correct_answer,
        figure: @figure,
        figure_image_base64: @figure_image_base64
      }
    end
  end
end
