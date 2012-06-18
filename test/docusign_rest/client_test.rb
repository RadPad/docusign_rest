require 'helper'

describe DocusignRest::Client do

  before do
    @keys = DocusignRest::Configuration::VALID_CONFIG_KEYS
  end

  describe 'with module configuration' do
    before do
      DocusignRest.configure do |config|
        @keys.each do |key|
          config.send("#{key}=", key)
        end
      end
    end

    after do
      DocusignRest.reset
    end

    it "should inherit module configuration" do
      api = DocusignRest::Client.new
      @keys.each do |key|
        api.send(key).must_equal key
      end
    end

    describe 'with class configuration' do
      before do
        @config = {
          :username       => 'un',
          :password       => 'pd',
          :integrator_key => 'ik',
          :account_id     => 'ai',
          :format         => 'fm',
          :endpoint       => 'ep',
          :api_version    => 'av',
          :user_agent     => 'ua',
          :method         => 'md',
        }
      end

      it 'should override module configuration' do
        api = DocusignRest::Client.new(@config)
        @keys.each do |key|
          api.send(key).must_equal @config[key]
        end
      end

      it 'should override module configuration after' do
        api = DocusignRest::Client.new

        @config.each do |key, value|
          api.send("#{key}=", value)
        end

        @keys.each do |key|
          api.send("#{key}").must_equal @config[key]
        end
      end
    end
  end

  describe 'client' do
    before do
      DocusignRest.configure do |config|
        config.username       = 'your_username/email'
        config.password       = 'your_password'
        config.integrator_key = 'your_integrator_key'
        config.account_id     = 'your_account_id_provided_by_the_rake_task'
      end
      @client = DocusignRest::Client.new
    end

    it "should allow access to the auth headers after initialization" do
      @client.must_respond_to :docusign_authentication_headers
    end

    it "should allow access to the acct_id after initialization" do
      @client.must_respond_to :acct_id
    end

    it "should allow creating an envelope from a document" do
      VCR.use_cassette "create_envelope/from_document" do
        response = @client.create_envelope_from_document(
          email: {
            subject: "test email subject",
            body: "this is the email body and it's large!"
          },
          signers: [
            {email: 'jonkinney+doc@gmail.com', name: 'Test Guy'},
            {email: 'jonkinney+doc2@gmail.com', name: 'Test Girl'}
          ],
          files: [
            {path: 'test.pdf', name: 'test.pdf'},
            {path: 'test2.pdf', name: 'test2.pdf'}
          ],
          status: 'sent'
        )
        response = JSON.parse(response.body)
        response["status"].must_equal "sent"
      end
    end

    describe "embedded signing" do
      before do
        # create the template dynamically
        VCR.use_cassette("create_template", record: :all)  do
          response = @client.create_template(
            description: 'Cool Description',
            name: "Cool Template Name",
            signers: [
              {
                email: 'jonkinney@gmail.com',
                name: 'jon',
                role_name: 'Issuer',
                anchor_string: 'sign here',
                sign_here_tab_text: 'Issuer, Please Sign Here',
                template_locked: true, #doesn't seem to do anything that I can tell
                template_required: true, #doesn't seem to do anything that I can tell
                email_notification: false
              }
            ],
            files: [
              {path: 'test.pdf', name: 'test.pdf'}
            ]
          )
          @template_response = JSON.parse(response.body)
        end

        # use the templateId to get the envelopeId
        VCR.use_cassette("create_envelope/from_template", record: :all)  do
          response = @client.create_envelope_from_template(
            status: 'sent',
            email: {
              subject: "The test email subject envelope",
              body: "Envelope body content here"
            },
            template_id: @template_response["templateId"],
            template_roles: [
              {
                email: 'jonkinney@gmail.com',
                name: 'jon',
                role_name: 'Issuer'
              }
            ]
          )
          @envelope_response = JSON.parse(response.body)
        end
      end

      it "should return a URL for embedded signing" do
        #ensure template was created
        @template_response["templateId"].wont_be_nil
        @template_response["name"].must_equal "Cool Template Name"

        #ensure creating an envelope from a dynamic template did not error
        @envelope_response["errorCode"].must_be_nil

        #return the URL for embedded signing
        VCR.use_cassette("get_recipient_view", record: :all)  do
          response = @client.get_recipient_view(
            envelope_id: @envelope_response["envelopeId"],
            email: 'jonkinney@gmail.com',
            return_url: 'http://google.com',
            user_name: 'jon'
          )
          @view_recipient_response = JSON.parse(response.body)
          puts @view_recipient_response
        end
      end

    end

  end

end
