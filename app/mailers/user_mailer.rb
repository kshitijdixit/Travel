class UserMailer < ApplicationMailer
	default from: "support@example.com"

	#Booking user email
  def booking_client_email(booking)
  	@booking = booking
  	@user = booking.try(:user)
		@property = booking.try(:property)
		mail(to: @user.email, subject: "Your have successfully booked #{@property.try(:name)}")
  end

  #Booking property owner email
  def booking_owner_email(booking)
  	@booking = booking
  	@user = booking.try(:user)
  	@owner = booking.try(:property).try(:user)
		@property = booking.try(:property)
		mail(to: @owner.email, subject: "Your property booked by #{@user.try(:name)}")
  end

  #Booking confirmation user email
  def booking_confirmation_client_email(payment)
    @payment = payment
    @booking = payment.try(:booking)
    @property = @booking.try(:property)
    @user = payment.try(:user)
    @owner = @property.try(:user)
    mail(to: @user.email, subject: "Your booking is confirmed")
  end

  #Booking confirmation owner email
  def booking_confirmation_owner_email(payment)
    @payment = payment
    @booking = payment.try(:booking)
    @property = @booking.try(:property)
    @user = payment.try(:user)
    @owner = @property.try(:user)
    mail(to: @owner.email, subject: "Your property booking is confirmed by #{@user.try(:name)}")
  end
end