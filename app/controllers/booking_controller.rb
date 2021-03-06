class BookingController < ApplicationController
	before_action :authenticate_user!,  only: [:book_now, :create, :pay_now, :view_invoice]
	before_action :get_property,  only: [:create, :pay_now, :book_now, :get_type_price, :patym_webhook]
	before_action :get_booking,  only: [:patym_webhook, :pay_now, :view_invoice]
	skip_before_filter :verify_authenticity_token, only: [:patym_webhook, :freecharge_failer, :freecharge_success]
	include PaytmHelper

	def patym_webhook
		#payuMoney
		if params[:payuMoneyId].present?
			if params[:status].eql?('success')
				@payment = current_user.payments.new()
				@payment.create_payment_payumoney(params, @booking.id)
				if @payment.save
					#PaymentWorker.perform_async(@payment.id)
					@payment.set_booking_status
					flash[:notice] = "Your booking is successfully confirmed" 
				else
					flash[:alert] = "Transaction status is failure #{params[:error_Message]}" 
				end
			else
				flash[:alert] = "Transaction status is failure #{params[:error_Message]}"
			end
		#Paytm
		else
			if params[:STATUS].eql?('TXN_SUCCESS')
				@payment = current_user.payments.new()
				@payment.create_payment(params, @booking.id)
				if @payment.save
					# PaymentWorker.perform_async(@payment.id)
					@payment.set_booking_status
					flash[:notice] = "Your booking is successfully confirmed" 
				else
					flash[:alert] = "Transaction status is failure #{params[:RESPMSG]}" 
				end
			else
				flash[:alert] = "Transaction status is failure #{params[:RESPMSG]}"
			end
		end	

		redirect_to pay_now_property_booking_path(@property,@booking)
	end 

	def pay_now
		#Pay u Money
		@paramListPayumoney = @booking.params_list_payumoney
		@paramListPayumoney["furl"] = patym_webhook_property_booking_url(@property,@booking)
		@paramListPayumoney["surl"] = patym_webhook_property_booking_url(@property,@booking)

		#Paytm
    @paramListPaytm = @booking.params_list_patym
    @paramListPaytm["CALLBACK_URL"] = patym_webhook_property_booking_url(@property,@booking)
		@paramListPaytm["CHECKSUMHASH"] = new_pg_checksum(@paramListPaytm, ENV['PAYTM_MERCHANT_KEY']).gsub("\n",'')
	end

	def book_now
	end

	def view_invoice
		@payment = @booking.payment
	end

	def create
		@booking = current_user.bookings.new(booking_params)
		@booking.seats = params[:booking][:seats]
    respond_to do |format|
      if @booking.save
      	#BookingWorker.perform_async(@booking.id)
      	@booking.send_mail_to_owner
        format.html { redirect_to pay_now_property_booking_path(@property, @booking), notice: 'Booking was successfully created.' }
      else
        format.html { render :book_now }
      end
    end
	end

	def get_type_price
		seats  = []
		remaining_seats = 0
		property_type = PropertyType.find_by_name(params[:type])
		@property_price = @property.property_prices.where(property_type_id: property_type.id).first
		booked_seats  = @property.bookings.where(book_type: params[:type]).where('DATE(?) BETWEEN start_date AND end_date', params[:start_date].to_date)
		#Booked seats
		if params[:type].eql?("Meeting/Conference Room")
			seats << @property_price.childrens.map{|c| c.seats} if @property_price.childrens.present?
			booked_seats = booked_seats.map{|b| JSON(b.seats)}.flatten.map(&:to_i)
			seats  = booked_seats.present? ? seats.flatten - booked_seats : seats
		else
			booked_seats = booked_seats.map{|b| JSON(b.seats)}.flatten.map(&:to_i).reduce(&:+)
			remaining_seats  = booked_seats.present? ? @property_price.try(:seats) - booked_seats : @property_price.try(:seats) 
		end
		respond_to do |format|
	  format.json { render json: {property_price: @property_price, seats: seats.flatten, remaining_seats: remaining_seats} }  
	 end
	end

	protected
	def get_property
		@property = Property.find(params[:property_id])
	end

	def get_booking
		@booking = Booking.friendly.find(params[:id])	
	end

	def booking_params
		params[:booking][:rooms] = params[:booking][:seats].length > 1 ? params[:booking][:seats].length : nil
    params[:booking][:property_id] = @property.id
    params.require(:booking).permit(:user_id, :property_id, :name, :book_type, :phone, :rooms, :seats, :start_date, :end_date, :status, :total_amount)
  end
end
								