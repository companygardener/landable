require_dependency "landable/api_controller"

module Landable
  module Api
    class TemplatesController < ApiController
      # filters
      before_filter :load_template, except: [:create, :index]

      # RESTful methods
      def create
        template = Template.new(template_params)
        template.save!
        
        respond_with template, status: :created, location: template_url(template)
      end

      def destroy
        @template.temp_author = current_author
        @template.try(:deactivate)

        respond_with @template
      end

      def index
        respond_with Template.all
      end

      def show
        respond_with @template
      end

      def update
        @template.update_attributes!(template_params)
        
        respond_with @template
      end

      # custom methods
      def publish
        @template.publish! author_id: current_author.id, notes: params[:notes], is_minor: !!params[:is_minor]
        
        respond_with @template
      end

      def reactivate
        @template.try(:reactivate)
        
        respond_with @template
      end

      private
        def template_params
          params.require(:template).permit(:id, :name, :body, :description, :thumbnail_url, 
                                           :slug, :is_layout, :is_publishable,
                                           audit_flags: [])
        end

        def load_template
          @template = Template.find(params[:id])
        end
    end
  end
end
