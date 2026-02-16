# frozen_string_literal: true

require "docx"

module HamExamParser
  class DocxParser
    # Matches question ID with correct answer indicator, e.g. "T1A01 (C)"
    QUESTION_ID_RE = /\A\s*([TEG]\d[A-Z]\d{2})\s*\(([A-D])\)/i

    # Matches answer choice lines, e.g. "A. Some answer text" or "D.Some answer text"
    ANSWER_RE = /\A\s*([A-D])\.\s*(.+)/

    # Matches figure references in question text, e.g. "figure T-1", "Figure E5-1", "Figure E73"
    FIGURE_REF_RE = /figure\s+([TEG]\d*-?\d+)/i

    # Matches subelement headers, e.g. "SUBELEMENT T1 – FCC Rules..."
    SUBELEMENT_RE = /\A\s*SUBELEMENT\s+([TEG]\d)\s*[-–—]\s*(.+)/i

    # Matches group headers, e.g. "T1A - Purpose and permissible..."
    # Also handles formats without a dash, e.g. "T1A Purpose and permissible..."
    # Also handles the question count in brackets like [4 Exam Questions - 4 Groups]
    # The (?!\d) prevents matching errata lines like "G1A04 – question deleted"
    GROUP_RE = /\A\s*([TEG]\d[A-Z])(?!\d)\s*[-–—]?\s*(.+)/i

    attr_reader :questions, :subelements

    def initialize(file_path)
      @file_path = file_path
      @questions = []
      @subelements = {}
    end

    def parse
      doc = Docx::Document.open(@file_path)
      paragraphs = doc.paragraphs.map(&:text)

      current_subelement = nil
      current_group = nil
      current_question = nil
      collecting_question_text = false
      found_first_subelement = false

      paragraphs.each do |line|
        line = line.strip
        next if line.empty?

        # Skip preamble/errata content before the first subelement header
        unless found_first_subelement
          if (match = line.match(SUBELEMENT_RE))
            found_first_subelement = true
          else
            next
          end
        end

        # Check for subelement header
        if (match = line.match(SUBELEMENT_RE))
          found_first_subelement = true
          save_question(current_question) if current_question
          current_question = nil
          collecting_question_text = false

          sub_id = match[1].upcase
          sub_title = match[2].strip
          current_subelement = sub_id
          @subelements[sub_id] ||= { id: sub_id, title: sub_title, groups: {} }
          next
        end

        # Check for group header
        if (match = line.match(GROUP_RE)) && !line.match(QUESTION_ID_RE)
          group_id = match[1].upcase
          # Only treat as group header if it matches expected subelement prefix
          if current_subelement && group_id.start_with?(current_subelement)
            save_question(current_question) if current_question
            current_question = nil
            collecting_question_text = false

            group_title = match[2].strip.sub(/\s*\[.*\]\s*\z/, "").strip
            current_group = group_id
            if @subelements[current_subelement]
              @subelements[current_subelement][:groups][group_id] ||= {
                id: group_id, title: group_title, questions: []
              }
            end
            next
          end
        end

        # Check for question ID line
        if (match = line.match(QUESTION_ID_RE))
          save_question(current_question) if current_question

          q_id = match[1].upcase
          correct = match[2].upcase

          # Derive subelement/group from question ID
          derived_subelement = q_id[0, 2]
          derived_group = q_id[0, 3]

          # Update current context if needed
          if derived_subelement != current_subelement && !@subelements[derived_subelement]
            current_subelement = derived_subelement
            @subelements[derived_subelement] = { id: derived_subelement, title: "", groups: {} }
          end
          current_subelement ||= derived_subelement

          if !@subelements[current_subelement][:groups][derived_group]
            current_group = derived_group
            @subelements[current_subelement][:groups][derived_group] = {
              id: derived_group, title: "", questions: []
            }
          end
          current_group = derived_group

          # Check if question text follows on same line after the ID pattern
          remainder = line.sub(QUESTION_ID_RE, "").strip
          # Also strip trailing reference in brackets like [97.1]
          reference = nil
          if (ref_match = remainder.match(/\[(.+?)\]\s*\z/))
            reference = ref_match[1]
            remainder = remainder.sub(/\s*\[.+?\]\s*\z/, "").strip
          end

          current_question = Question.new(
            id: q_id,
            subelement: current_subelement,
            group: current_group,
            correct_answer: correct,
            reference: reference,
            question: "",
            answers: {}
          )
          collecting_question_text = true

          # If there's text remaining after the ID, it's the start of the question
          current_question.question = remainder unless remainder.empty?
          next
        end

        next unless current_question

        # Check for answer choice
        if (match = line.match(ANSWER_RE))
          collecting_question_text = false
          current_question.answers[match[1]] = match[2].strip
          next
        end

        # If we're still collecting question text (between ID line and first answer)
        if collecting_question_text
          # Check for figure reference
          if (fig_match = line.match(FIGURE_REF_RE))
            current_question.figure = fig_match[1]
          end

          if current_question.question.empty?
            current_question.question = line
          else
            current_question.question += " #{line}"
          end
        end
      end

      # Don't forget the last question
      save_question(current_question) if current_question

      self
    end

    def to_structured_hash(exam_class: nil, pool_year: nil)
      {
        exam_class: exam_class || detect_exam_class,
        pool_year: pool_year,
        subelements: @subelements.values.sort_by { |s| s[:id] }.map do |sub|
          {
            id: sub[:id],
            title: sub[:title],
            groups: sub[:groups].values.sort_by { |g| g[:id] }.map do |grp|
              {
                id: grp[:id],
                title: grp[:title],
                questions: grp[:questions].sort_by(&:id).map(&:to_h)
              }
            end
          }
        end
      }
    end

    def attach_images(encoder)
      @questions.each do |q|
        next unless q.figure

        encoded = encoder.encode(q.figure)
        q.figure_image_base64 = encoded if encoded
      end
    end

    private

    def save_question(question)
      return unless question

      # Also check question text for figure references if not already set
      if question.figure.nil? && question.question
        if (fig_match = question.question.match(FIGURE_REF_RE))
          question.figure = fig_match[1]
        end
      end

      @questions << question

      sub = @subelements[question.subelement]
      if sub
        group = sub[:groups][question.group]
        group[:questions] << question if group
      end
    end

    def detect_exam_class
      return nil if @subelements.empty?

      prefix = @subelements.keys.first[0]
      case prefix
      when "T" then "technician"
      when "G" then "general"
      when "E" then "extra"
      end
    end
  end
end
