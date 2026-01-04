# frozen_string_literal: true

module AnimeDatabase
  class AnimeEpisodeTopic < ActiveRecord::Base
    self.table_name = 'anime_episode_topics'

    belongs_to :topic, class_name: 'Topic', foreign_key: :topic_id

    validates :anime_id, presence: true
    validates :episode_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :topic_id, presence: true, uniqueness: { scope: [:anime_id, :episode_number] }

    scope :for_anime, ->(anime_id) { where(anime_id: anime_id) }
    scope :recent, -> { order(aired_at: :desc) }

    def self.find_or_create_for_episode(anime_id:, episode_number:, anime_title:, aired_at: nil)
      find_by(anime_id: anime_id, episode_number: episode_number) || 
        create_discussion_topic(anime_id: anime_id, episode_number: episode_number, anime_title: anime_title, aired_at: aired_at)
    end

    def self.create_discussion_topic(anime_id:, episode_number:, anime_title:, aired_at:)
      return nil unless SiteSetting.anime_auto_episode_discussions

      category_id = SiteSetting.anime_episode_category.presence&.to_i
      return nil if category_id.blank?

      title = "[Anime] #{anime_title} - Episode #{episode_number} Discussion"
      
      raw_body = <<~POST
        Episode #{episode_number} of **#{anime_title}** has aired!

        **Anime**: #{anime_title}
        **Episode**: #{episode_number}
        **Air Date**: #{aired_at&.strftime('%B %d, %Y') || 'Unknown'}

        [View Anime Details](/anime/#{anime_title.to_s.parameterize.presence || anime_id})

        ---
        **Discuss the episode below! Please use spoiler tags for major plot points.**
      POST

      topic = Topic.create!(
        title: title,
        user: Discourse.system_user,
        category_id: category_id,
        archetype: Archetype.default
      )

      PostCreator.create!(
        Discourse.system_user,
        topic_id: topic.id,
        raw: raw_body,
        skip_validations: true
      )

      create!(
        anime_id: anime_id,
        episode_number: episode_number,
        topic_id: topic.id,
        aired_at: aired_at || Time.current
      )
    rescue => e
      Rails.logger.error("Failed to create episode discussion: #{e.message}")
      nil
    end
  end
end
