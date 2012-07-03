module Acts
  module Elo
    class Calculator
      class << self
        def default_elo_options
          {
            :default_rank => 1200,
            :proficiency_map => {
              :coefficients => [30, 15, 10],
              :rank_limits  => [1299, 2399]
            }
          }
        end
        def result_map
          {
            :win => 1.0,
            :lose => 0.0,
            :draw => 0.5
          }
        end

        # Available options are:
        # * default_rank - change the starting rank
        # * proficiency_map - hash that has two keys
        #    * rank_limits  - array of two elements, ranks that limit categories of
        #                     player proficiency. Between novice and intermediate; intermediate and pro.
        #                     Defaults: 1299, 2399
        #    * coefficients - proficiency coefficient for each category.
        #                     Defaults: 30 for novice, 15 for intermediate, 10 for a pro
        def get_new_elo_for_float(points, current_elo, opponent_elo, options = {})
          opts = default_elo_options.merge(options)
          current_elo ||= opts[:default_rank]

          # Formula from: http://en.wikipedia.org/wiki/Elo_rating_system
          diff        = opponent_elo.to_f - current_elo.to_f
          expected    = 1 / (1 + 10 ** (diff / 400))
          coefficient = opts[:proficiency_map][:coefficients][1]

          if current_elo < opts[:proficiency_map][:rank_limits].first
            coefficient = opts[:proficiency_map][:coefficients].first
          end

          if current_elo > opts[:proficiency_map][:rank_limits].last
            coefficient = opts[:proficiency_map][:coefficients].last
          end

          (current_elo + coefficient*(points-expected)).round
        end
        def get_new_elo_for_win(current_elo, opponent_elo, opts = {})
          get_new_elo_for_float(result_map[:win], current_elo, opponent_elo, opts)
        end
        def get_new_elo_for_lose(current_elo, opponent_elo, opts = {})
          get_new_elo_for_float(result_map[:lose], current_elo, opponent_elo, opts)
        end
        def get_new_elo_for_draw(current_elo, opponent_elo, opts = {})
          get_new_elo_for_float(resul_map[:draw], current_elo, opponent_elo, opts)
        end
      end
    end

    def self.included(base)
      base.class.send(:attr_accessor, :acts_as_elo_options)

      # `acts_as_elo` hooks into your object to provide you with the ability to
      # set and get `elo_rank` attribute
      # Available options are:
      # * default_rank - change the starting rank
      # * one_way - limits update of the rank to only self
      # * proficiency_map - hash that has two keys
      #    * rank_limits  - array of two elements, ranks that limit categories of
      #                     player proficiency. Between novice and intermediate; intermediate and pro.
      #                     Defaults: 1299, 2399
      #    * coefficients - proficiency coefficient for each category.
      #                     Defaults: 30 for novice, 15 for intermediate, 10 for a pro
      def base.acts_as_elo(opts = {})
        self.acts_as_elo_options = Calculator.default_elo_options.merge(opts)
        if Object::const_defined?("ActiveRecord") && self.ancestors.include?(ActiveRecord::Base)
          define_method :assign_default_elo do
            self.elo_rank ||= self.class.acts_as_elo_options[:default_rank]
          end
          after_initialize :assign_default_elo
        else
          define_method :elo_rank do
            @elo_rank || self.class.acts_as_elo_options[:default_rank]
          end
          define_method :elo_rank= do |elo_rank|
            @elo_rank = elo_rank
          end
        end
      end
    end

    def elo_win!(opponent, opts={})
      elo_update(opponent, opts.merge(:result => :win))
    end

    def elo_lose!(opponent, opts={})
      elo_update(opponent, opts.merge(:result => :lose))
    end

    def elo_draw!(opponent, opts={})
      elo_update(opponent, opts.merge(:result => :draw))
    end

    def elo_update(opponent, opts={})
      opts = self.class.acts_as_elo_options.merge(opts)

      points = Calculator.result_map[opts.delete(:result)]
      one_way = opts.delete(:one_way)
      old_elo = self.elo_rank
      self.elo_rank = Calculator.get_new_elo_for_float(points, self.elo_rank, opponent.elo_rank, opts)
      opponent.elo_rank = Calculator.get_new_elo_for_float(1.0 - points, opponent.elo_rank, old_elo, opts) unless one_way
    end
  end
end
