class Payment < ApplicationRecord
  belongs_to :user
  acts_as_paranoid

  
  validate :validate_payment_method
  
  #validate :validate_payment_method, :validate_payment_status

  def accepted_payment_methods
    ['Depósito', 'Transferência', 'Presencial']
  end

  def accepted_payment_status
    ['Aguardando' ,'Pendente', 'Confirmado']
  end

  def validate_payment_method
    errors.add("Método de pagamento","é inválido.") unless payment_method_is_valid?
  end

  def validate_payment_status
    errors.add("Status do pagamento","é inválido.") unless payment_status_is_valid?
  end

  def payment_method_is_valid?
    self.accepted_payment_methods.include? self.method
  end

  def payment_status_is_valid?
    self.accepted_payment_status.include? self.status
  end



  def price_pagseguro
    percert_taxa = 0.0399
    fixed_taxa = 0.4
    total = (set_price + fixed_taxa) / (1 - percert_taxa)
    return '%.2f' % total
  end

  def pay_pagseguro
    update(price: set_price) unless set_price.nil?
    payment = PagSeguro::PaymentRequest.new

    payment.reference = "REFl#{self.user.lot_id}user#{self.user.id}"

    if Rails.env.development? || Rails.env.test?
      payment.notification_url = 'http://localhost:3000/confirm_payment'
      payment.redirect_url = 'http://localhost:3000/'
    else
      payment.notification_url = 'https://rjfej17.herokuapp.com/confirm_payment'
      payment.redirect_url = 'http://www.efej.com.br'
    end

    payment.items << {
      id: self.user.id,
      description: "#{self.user.lot.name} #{set_name_description} #{set_name_host}" ,
      amount: price_pagseguro
    }

    payment.sender = {
      email: self.user.email,
      cpf: self.user.cpf.numero.only_numbers,
      phone: {
        area_code: self.user.phone.only_numbers[0..1],
        number: self.user.phone.only_numbers[2..10]
      }
    }

    response = payment.register

    if response.errors.any?
      raise response.errors.join("\n")
    else
      update(url_pagseguro: response.url)
    end
  end

end
