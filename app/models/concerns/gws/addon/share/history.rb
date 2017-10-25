module Gws::Addon::Share
  module History
    extend ActiveSupport::Concern
    extend SS::Addon

    included do
      after_save :save_history_for_save
      after_destroy :save_history_for_destroy
    end

    def histories
      @histroies ||= Gws::Share::History.where(model: reference_model, item_id: id)
    end

    def skip_gws_history
      @skip_gws_history = true
    end

    private

    def save_history_for_save
      return if @db_changes.blank?

      if @db_changes.key?('_id')
        save_history mode: 'create'
      else
        save_history mode: 'update', updated_fields: @db_changes.keys.reject { |s| s =~ /_hash$/ }
      end
    end

    def save_history_for_destroy
      save_history mode: 'delete' # @flagged_for_destroy
    end

    def save_history(overwrite_params = {})
      return if @skip_gws_history

      site_id = @cur_site.try(:id)
      site_id ||= self.site_id rescue nil
      return unless site_id

      item = Gws::Share::History.new(
        cur_user: @cur_user,
        site_id: site_id,
        name: reference_name,
        model: reference_model,
        uploadfile_name: "temporary",
        uploadfile_filename: "temporary",
        uploadfile_size: 100,
        uploadfile_content_type: "temporary",
        uploadfile_path: "temporary",
        item_id: id
      )
      item.attributes = overwrite_params
      item.save
    end
  end
end
