require_relative 'spec_helper'

describe "Rabobank" do

  context "parse whole file" do
    let(:file_name) { File.dirname(__FILE__) + '/fixtures/rabobank.txt' }
    let(:bank_statements) { MT940::Base.parse_mt940(file_name) }

    it "should have the correct number of bank account's" do
      bank_statements.keys.size.should == 1
    end

    it "should have the correct number of bank statements per bank account" do
      bank_statements["212121211"].size.should == 23
    end

    context MT940::BankStatement do
      let(:bank_statements_for_account) { bank_statements["212121211"] }

      it "should have the correct number of transactions per bank statement" do
        bank_statements_for_account[0].transactions.size.should == 1
        bank_statements_for_account[1].transactions.size.should == 0
        bank_statements_for_account[10].transactions.size.should == 2
      end

      context "single bank statement" do
        let(:bank_statement) { bank_statements_for_account[0] }

        it "should have a correct previous balance per statement" do
          balance = bank_statement.previous_balance
          balance.amount.should == 17431.67
          balance.date.should == Date.new(2012, 9, 28)
          balance.currency.should == "EUR"
        end

        it "should have a correct next balance per statement" do
          balance = bank_statement.new_balance
          balance.amount.should == 17381.67
          balance.date.should == Date.new(2012, 10, 1)
          balance.currency.should == "EUR"
        end

        context "debit transaction" do

          let(:transaction) { bank_statement.transactions.first }

          it "should have the correct amount" do
            transaction.amount.should == -50
          end

          it "should have a description" do
            transaction.description.should == "Incasso deposit Savings Account"
          end

          it "should have an account number" do
            transaction.bank_account.should == "212121211"
          end

          it "should have a contra account number" do
            transaction.contra_account.should == "1313131319"
          end

          it "should have a contra account owner" do
            transaction.contra_account_owner.should == "J. DOE"
          end

          it "should have a bank" do
            transaction.bank.should == "Rabobank"
          end

          it "should have a currency" do
            transaction.currency.should == "EUR"
          end

          it "should have a date" do
            transaction.date.should == Date.new(2012, 10, 1)
          end

          it "should have a type" do
            transaction.type.should == "Machtiging Rabobank"
          end

        end

      end

      context "credit transaction" do
        let(:transaction) { bank_statements_for_account[12].transactions[1] }

        it "should have the correct amount" do
          transaction.amount.should == 12100.00
        end

        it "should have the correct type" do
          transaction.type.should == "Bijschrijving betaalopdracht"
        end

        it "should have the correct contra account" do
          transaction.contra_account.should == "987654321"
        end

        it "should have the correct contra account owner" do
          transaction.contra_account_owner.should == "COMPANY B.V."
        end

      end

      context "transaction with a GIRO number" do
        let(:transaction) { bank_statements_for_account[18].transactions.first }

        it "should have the correct contra account" do
          transaction.contra_account.should == "2445588"
        end

        it "should have the correct contra account owner" do
          transaction.contra_account_owner.should == "Belastingdienst"
        end
      end

      context "with a unknown contra account" do
        let(:transaction) { bank_statements_for_account[3].transactions.first }

        it "should have a NONREF as contra account" do
          transaction.contra_account.should == "NONREF"
        end

        it "should have a contra account owner" do
          transaction.contra_account_owner.should == "Kosten"
        end

        it "should have a type" do
          transaction.type.should == "Afschrijving rente provisie kosten"
        end
      end

      context "multi line description" do
        let(:transaction) { bank_statements_for_account[5].transactions.first }

        it "should have the correct description" do
          transaction.description.should == "BETALINGSKENM.  490022201282 ARBEIDS ONG. VERZ. 00333333333 PERIODE 06.10.2012 - 06.11.2012"
        end

        it "should have a type" do
          transaction.type.should == "Doorlopende machtiging algemeen"
        end
      end
    end

  end

  context "mt 940 structured" do
    let(:file_name) { File.dirname(__FILE__) + '/fixtures/rabobank_mt940_structured.txt' }
    let(:bank_statements) { MT940::Base.parse_mt940(file_name) }

    it "should have the correct number of bank account's" do
      bank_statements.keys.size.should == 1
    end

    it "should have the correct number of bank statements per bank account" do
      bank_statements["123456789"].size.should == 2
    end

    context MT940::BankStatement do
      let(:bank_statements_for_account) { bank_statements["123456789"] }

      it "should have the correct number of transactions per bank statement" do
        bank_statements_for_account[0].transactions.size.should == 2
        bank_statements_for_account[1].transactions.size.should == 8
      end

      context "single bank statement" do
        let(:bank_statement) { bank_statements_for_account[0] }

        it "should have a correct previous balance per statement" do
          balance = bank_statement.previous_balance
          balance.amount.should == 1147.95
          balance.date.should == Date.new(2013, 4, 2)
          balance.currency.should == "EUR"
        end

        it "should have a correct next balance per statement" do
          balance = bank_statement.new_balance
          balance.amount.should == 1190.35
          balance.date.should == Date.new(2013, 4, 3)
          balance.currency.should == "EUR"
        end

        context "debit transaction" do

          let(:transaction) { bank_statement.transactions.first }

          it "should have the correct amount" do
            transaction.amount.should == -127.5
          end

          it "should have a description" do
            transaction.description.should == "674725433 1120000153447185 14144467636004962"
          end

          it "should have an account number" do
            transaction.bank_account.should == "123456789"
          end

          it "should have an iban number" do
            transaction.bank_account_iban.should == "NL50RABO0123456789"
          end

          it "should have a contra account number" do
            transaction.contra_account.should == "523149468"
          end

          it "should have a contra account iban" do
            transaction.contra_account_iban.should == "NL96RBOS0523149468"
          end

          it "should have a contra account owner" do
            transaction.contra_account_owner.should == "Nespresso Nederland B.V."
          end

          it "should have a bank" do
            transaction.bank.should == "Rabobank"
          end

          it "should have a currency" do
            transaction.currency.should == "EUR"
          end

          it "should have a date" do
            transaction.date.should == Date.new(2013, 4, 3)
          end

          it "should have a type" do
            transaction.type.should == "Betaalopdracht iDEAL"
          end

        end

      end

      context "credit transaction" do
        let(:transaction) { bank_statements_for_account[0].transactions[1] }

        it "should have the correct amount" do
          transaction.amount.should == 169.90
        end

        it "should have the correct type" do
          transaction.type.should == "Bijschrijving crediteurenbetaling"
        end

        it "should have the correct contra account" do
          transaction.contra_account.should == "NONREF"
        end

        it "should have the correct contra account iban" do
          transaction.contra_account_iban.should be_nil
        end

        it "should have the correct contra account owner" do
          transaction.contra_account_owner.should == "Bedrijf B.V."
        end

      end

      context "transaction with a GIRO number" do
        let(:transaction) { bank_statements_for_account[1].transactions.first }

        it "should have the correct contra account" do
          transaction.contra_account.should == "4500018"
        end

        it "should have the correct contra account iban" do
          transaction.contra_account_iban.should == "4500018"
        end

        it "should have the correct contra account owner" do
          transaction.contra_account_owner.should == "DIVV afd parkeergebouwewn"
        end
      end

      context "with a unknown contra account" do
        let(:transaction) { bank_statements_for_account[1].transactions[3] }

        it "should have a NONREF as contra account" do
          transaction.contra_account.should == "NONREF"
        end

        it "should have a nil as contra account iban" do
          transaction.contra_account_iban.should be_nil
        end

        it "should have a type" do
          transaction.type.should == "Afschrijving rente provisie kosten"
        end
      end

      context 'without a proper description' do
        let(:transaction) { bank_statements_for_account[1].transactions[4] }

        it 'should have an empty description' do
          transaction.description.should == ''
        end
      end

      context 'with IBAN and BIC' do
        let(:transaction) { bank_statements_for_account[1].transactions[7] }

        it 'should have BIC' do
          transaction.contra_account_bic.should == 'INGBNL2A'
        end
      end

    end
  end

  it "should be able to handle a debet current balance" do
    debet_file_name = File.dirname(__FILE__) + '/fixtures/rabobank_with_debet_previous_balance.txt'
    bank_statement = MT940::Base.parse_mt940(debet_file_name)["129199348"].first

    bank_statement.previous_balance.amount.should == -12
    bank_statement.previous_balance.currency.should == "EUR"
    bank_statement.previous_balance.date.should == Date.new(2012, 10, 4)

    bank_statement.new_balance.amount.should == -12
    bank_statement.new_balance.currency.should == "EUR"
    bank_statement.new_balance.date.should == Date.new(2012, 10, 5)
  end

end
