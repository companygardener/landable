require 'spec_helper'

module Landable
  describe Page do
    it { should be_a HasAssets }
    it { should_not have_valid(:status_code).when(nil,'') }
    it { should have_valid(:status_code).when(200, 301, 302, 410) }
    it { should_not have_valid(:status_code).when(201, 303, 405, 500, 404) }

    # config.reserved_paths = %w(/reserved_path_set_in_initializer /reject/.* /admin.*)
    context 'PathValidator' do
      it { should_not have_valid(:path).when(nil, '', '/reserved_path_set_in_initializer') }
      it { should_not have_valid(:path).when('/reject/this', '/admin', '/ADMIN', '/admin_something' '/admin/path') }
      it { should     have_valid(:path).when('/reserved_path_set_in_initializer_not', '/do/not/reject/path', '/', '/rejectwhatever', '/reject') }
    end

    it 'should set is_publishable to true on before_save' do
      page = FactoryGirl.build :page, is_publishable: false
      page.save!
      page.is_publishable.should be_true
    end

    specify "#redirect?" do
      Page.new.should_not be_redirect
      Page.new().should_not be_redirect
      Page.new(status_code: 200).should_not be_redirect
      Page.new(status_code: 410).should_not be_redirect

      Page.new(status_code: 301).should be_redirect
      Page.new(status_code: 302).should be_redirect
    end

    describe '#published?' do
      context 'when published' do
        it 'should be true' do
          page = create :page
          page.publish! author: create(:author), notes: 'yo'
          page.should be_published
        end
      end

      context 'when not published' do
        it 'should be false' do
          page = create :page
          page.should_not be_published
        end
      end
    end

    specify '#path_extension' do
      Page.new(path: 'foo').path_extension.should be_nil
      Page.new(path: 'foo.bar').path_extension.should == 'bar'
      Page.new(path: 'foo.bar.baz').path_extension.should == 'baz'
      Page.new(path: 'foo.bar-baz').path_extension.should be_nil
    end

    describe '#content_type' do
      def content_type_for path
        Page.new(path: path).content_type
      end

      it 'should be text/html for html pages' do
        content_type_for('asdf').should == 'text/html'
        content_type_for('asdf.htm').should == 'text/html'
        content_type_for('asdf.html').should == 'text/html'
      end

      it 'should be application/json for json' do
        content_type_for('asdf.json').should == 'application/json'
      end

      it 'should be application/xml for xml' do
        content_type_for('asdf.xml').should == 'application/xml'
      end

      it 'should be text/plain for everything else' do
        content_type_for('foo.bar').should == 'text/plain'
        content_type_for('foo.txt').should == 'text/plain'
      end
    end

    describe '#html?' do
      let(:page) { build :page }

      it 'should be true if content_type is text/html' do
        page.should_receive(:content_type) { 'text/html' }
        page.should be_html
      end

      it 'should be false if content_type is not text/html' do
        page.should_receive(:content_type) { 'text/plain' }
        page.should_not be_html
      end
    end

    describe '#redirect_url' do
      it 'is required if redirect?' do
        page = Page.new status_code: 301
        page.should_not have_valid(:redirect_url).when(nil, '')
        page.should have_valid(:redirect_url).when('http://example.com', 'http://www.somepath.com')
      end

      it 'not required for 200, 410' do
        page = Page.new
        page.should have_valid(:redirect_url).when(nil, '')
      end
    end

    describe '#meta_tags' do
      it { subject.should have_valid(:meta_tags).when(nil) }

      specify "quacks like a Hash" do
        # Note the change from symbol to string; thus, always favor strings.
        page = create :page, meta_tags: { keywords: 'foo' }

        # rails 4.0 preserves the symbol for this instance; rails 4.1 switches straight to strings
        page.meta_tags.keys.map(&:to_s).should == ['keywords']

        tags = Page.first.meta_tags
        tags.should be_a(Enumerable)
        tags.keys.should == ['keywords']
        tags.values.should == ['foo']
      end
    end

    describe '#head_content' do
      it { subject.should have_valid(:meta_tags).when(nil) }

      it 'works as a basic text area' do
        page = create :page, head_content: "<head en='en'/>"
        page.head_content.should ==  "<head en='en'/>"
        
        page.head_content = "<head en='magic'/>"
        page.save

        page.head_content.should == "<head en='magic'/>"
      end
    end

    describe '#path=' do
      it 'ensures a leading "/" on path' do
        Page.new(path: 'foo/bar').path.should == '/foo/bar'
      end

      it 'leaves nil and empty paths alone' do
        Page.new(path: '').path.should == ''
        Page.new(path: nil).path.should == nil
      end
    end

    describe '#publish' do
      let(:page) { FactoryGirl.create :page }
      let(:author) { FactoryGirl.create :author }

      it 'should create a page_revision' do
        expect {page.publish!(author: author)}.to change{page.revisions.count}.from(0).to(1)
      end

      it 'should have the provided author' do
        page.publish! author: author
        revision = page.revisions.last

        revision.author.should == author
      end

      it 'should update the published_revision_id' do
        page.publish! author: author
        revision = page.revisions.last

        page.published_revision.should == revision
      end

      it 'should set is_publishable to false' do
        page.is_publishable = true
        page.publish! author: author
        page.is_publishable.should be_false
      end

      it 'should unset previous revision.is_published' do
        page.publish! author: author
        revision1 = page.published_revision
        page.publish! author: author
        revision1.is_published.should be_false
      end
    end

    describe '#revert_to' do
      let(:page) { FactoryGirl.create :page }
      let(:author) { FactoryGirl.create :author }

      it 'should NOT update published_revision for the page' do
        page.title = 'Bar'
        page.publish! author: author
        revision = page.published_revision

        page.title = 'Foo'
        page.publish! author: author

        page.revert_to! revision

        page.published_revision.id.should_not == revision.id
      end

      it 'should copy revision attributes into the page model' do
        page.title = 'Bar'
        page.publish! author: author

        revision = page.published_revision

        page.title = 'Foo'
        page.save!
        page.publish! author: author

        # ensure assignment for all copied attributes
        keys = %w(title path body category_id theme_id status_code meta_tags redirect_url)
        keys.each do |key|
          page.should_receive("#{key}=").with(revision.send(key))
        end

        page.revert_to! revision
      end
    end

    describe '#forbid_changing_path' do
      context 'created_record' do
        it 'does not allow a path to be changed' do
          page = create :page, path: '/test'
          page.path = '/different'
          expect { page.save! }.to raise_error

          page.reload
          page.path.should == '/test'
        end
      end

      context 'new_record' do
        it 'allows the path to be changed' do
          page = build :page, path: '/test'
          page.save!

          page.path.should == '/test'
        end
      end
    end

    describe '#preview_path' do
      it 'should return the preview path' do
        page = build :page
        page.should_receive(:public_preview_page_path) { 'foo' }
        page.preview_path.should == 'foo'
      end
    end

    describe '#preview_url' do
      it 'should return the preview url' do
        page = build :page
        page.should_receive(:public_preview_page_url) { 'foo' }
        page.preview_url.should == 'foo'
      end
    end

    describe '::sitemappable' do
      let(:page) { create :page }
      let(:page_2) { create :page, :redirect }
      let(:page_3) { create :page, meta_tags: { 'robots' => 'noindex' } }

      it 'only returns pages with a status code of 200 and dont have a noindex tag' do 
        page_2.status_code.should == 301

        Landable::Page.sitemappable.should include(page)
        Landable::Page.sitemappable.should_not include(page_2, page_3)
      end
    end

    describe '#downcase_path' do
      it 'should force a path to be lowercase' do
        page = build :page, path: '/SEO'
        page.should be_valid
        page.path.should == '/seo'
      end

      it 'doesnt change a downcase path' do
        page = build :page, path: '/seo'
        page.should be_valid
        page.path.should == '/seo'
      end
    end

    describe '#redirect_url' do
      context 'validater' do
        before(:each) { @page = build :page, path: '/' }

        it 'should correctly validate http://' do
          @page.redirect_url = 'http://www.google.com'
          @page.should be_valid
        end

        it 'should correctly validate https://' do
          @page.redirect_url = 'http://www.google.com'
          @page.should be_valid
        end

        it 'should correctly validate /' do
          @page.redirect_url = '/some/uri'
          @page.should be_valid
        end

        it 'should not validate www' do
          @page.redirect_url = 'www.google.com'
          @page.should_not be_valid
        end

        it 'should not validate bad urls' do
          @page.redirect_url = 'hdasdfpou'
          @page.should_not be_valid
        end

      end
    end

    describe '::generate_sitemap' do
      it 'returns a sitemap' do
        page = create :page
        Landable::Page.generate_sitemap(host: 'example.com',
                                        protocol: 'http',
                                        exclude_categories: [],
                                        sitemap_additional_paths: []).should include("<loc>http://example.com#{page.path}</loc>")
      end

      it 'does not include excluded categories' do
        cat = create :category, name: 'Testing'
        page = create :page, category: cat
        Landable::Page.generate_sitemap(host: 'example.com',
                                        protocol: 'http',
                                        exclude_categories: ['Testing'],
                                        sitemap_additional_paths: []).should_not include("<loc>http://example.com#{page.path}</loc>")
      end

      it 'can handle https protocol' do
        page = create :page
        Landable::Page.generate_sitemap(host: 'example.com',
                                        protocol: 'https',
                                        exclude_categories: [],
                                        sitemap_additional_paths: []).should include("<loc>https://example.com#{page.path}</loc>")
      end

      it 'can handle additional pages' do
        Landable::Page.generate_sitemap(host: 'example.com',
                                        protocol: 'https',
                                        exclude_categories: [],
                                        sitemap_additional_paths: ['/terms.html']).should include("<loc>https://example.com/terms.html</loc>")
      end
    end

    describe '::by_path' do
      it 'returns first page with path name' do
        page  = create :page, path: '/seo'
        Landable::Page.by_path('/seo').should == page
      end
    end

    describe 'validate#body_strip_search' do
      it 'raises errors if errors!' do
        page = build :page, path: '/'
        page.body = "{% image_tag 'bad_image' %}"
        page.should_not be_valid
        page.errors[:body].should_not be_empty
      end

      it 'does not raise error when no syntax error' do
        page = build :page, path: '/'
        page.body = 'body'
        page.should be_valid
        page.save!
        page.body.should == 'body'
      end
    end
  end
end
