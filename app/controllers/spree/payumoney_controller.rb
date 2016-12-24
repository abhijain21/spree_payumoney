module Spree
  class PayumoneyController < StoreController
    protect_from_forgery only: :index
    
    before_filter :set_product_info, only: [:index, :confirm]
    
    def index
      @surl = payumoney_confirm_url
      @furl = payumoney_cancel_url
      
      payment_method = Spree::PaymentMethod.find(params[:payment_method_id])
      
      @service_url = payment_method.provider.service_url
      @merchant_key = payment_method.preferred_merchant_id

      @txnid = payment_method.txnid(current_order)
      @amount = current_order.total.to_s
      @email = current_order.email
      
      if(address = current_order.bill_address || current_order.ship_address)
        @phone = address.phone #udf2
        @firstname = address.firstname
        @lastname = address.lastname #udf1
        @city = address.city #udf3
      end
      #filling up all udfs
      #not sure if necessary by offsite payments
      @payment_method_id = payment_method.id #udf4
      
      @checksum = payment_method.checksum([@txnid, @amount, @productinfo, @firstname, @email, @lastname, @phone, @city, @payment_method_id, '', '', '', '', '', '']);
      @service_provider = payment_method.service_provider
    end

    def confirm
      payment_method = Spree::PaymentMethod.find(payment_method_id)
      order = current_order || raise(ActiveRecord::RecordNotFound)

      Spree::LogEntry.create({
        source: order,
        details: params.merge(payment: "Success").to_yaml
      })
      
      if(address = order.bill_address || order.ship_address)
        firstname = address.firstname
      end
      
      #confirm for correct hash and order amount requested before marking an payment as 'complete'
      checksum_matched = payment_method.checksum_ok?([params[:status], '', '', '', '', '',
        params[:udf5], params[:udf4], params[:udf3], params[:udf2], params[:udf1],
          params[:email], firstname, @productinfo, params[:amount], params[:txnid]], params[:hash])
      if !checksum_matched
        flash.alert = 'Malicious transaction detected.'
        redirect_to checkout_state_path(order.state)
        return
      end
      #check for order amount
      if !payment_method.amount_ok?(order.total, params[:amount])
        flash.alert = 'Malicious transaction detected. Order amount not matched.'
        redirect_to checkout_state_path(order.state)
        return
      end

      payment = order.payments.create!({
        source_type: 'Spree::Gateway::Payumoney',#could be something generated by system
        amount: order.total,
        payment_method: payment_method
      })

      #mark payment as paid/complete
      payment.complete

      order.next
      order.update_attributes({:state => "complete", :completed_at => Time.now})
                    
      if order.complete?
        order.update!
        flash.notice = Spree.t(:order_processed_successfully)

        redirect_to order_path(order)
        return
      else
        redirect_to checkout_state_path(order.state)
        return
      end
    end

    def cancel
      #log some entry into table
      Spree::LogEntry.create({
        source: current_order,
        details: params.merge(payment: "Failed").to_yaml
      })
      
      flash[:notice] = "Your Payumoney transaction has been cancelled / failed. Please try again."
      #redirect to payment path and ask user to complete checkout
      #with different payment method
      redirect_to checkout_state_path(current_order.state)
    end
    
    private
    def payment_method_id
      params[:udf4]
    end
    
    def set_product_info
      @productinfo = "DUMMYTEXT"
    end

  end
end
