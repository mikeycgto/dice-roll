require 'json'

class RollDice < Sinatra::Base
  helpers do
    def invalid_params
      @invalid_params_proc ||= lambda { |grp|
        return true if grp.size != 3

        sides = grp.first.to_i
        sides < 1 || sides > 2048
      }
    end

    def roll_die(sides)
      SecureRandom.random_number(sides) + 1
    end

    def roll_dice(sides, nd)
      nd.times.map { roll_die(sides) }
    end

    def roll_multiple_dice(sides, nd, nr)
      [[sides, nd], nr.times.map { roll_dice(sides, nd) }]
    end

    def grouped_params
      split = params[:splat].first.split('/').slice!(1..-1)
      split ||= []

      groups = split.each_slice(3).reject(&invalid_params)
      groups.map! { |grp| grp.map!(&:to_i) }
      groups
    end

    # Render as an array so order is preserved
    def render_json
      content_type :json

      @roll_results.to_a.to_json
    end

    def render_plain_text
      content_type :text

      @roll_results.inspect
    end
  end

  before '*' do
    last_splat = params[:splat].last
    last_split = last_splat.split('.')

    # Set @format, if any
    @format = last_split.last if last_split.size > 1

    # Always replace last splat
    params[:splat][-1] = last_split.first
  end

  # Groups of tuples where each tuple is like
  # /:sides/:number_of_dice/:number_of_roles
  get "*" do
    @roll_results = Hash[grouped_params.map { |grp|
      roll_multiple_dice(*grp)
    }]

    unless @roll_results.empty?
      case @format || request.accept.first.to_s
      when 'text/html', 'html' then haml :result, layout: :app
      when 'application/json', 'json' then render_json
      else render_plain_text
      end

    else redirect 'http://diceroll.onsimplybuilt.com'
    end
  end
end
