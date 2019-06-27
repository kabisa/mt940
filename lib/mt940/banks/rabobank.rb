class MT940::Rabobank < MT940::Base

  def self.determine_bank(*args)
    self if args[0].match(/^:940:/)
  end

  def parse_tag_61
    if @is_structured_format
      valuta_date = parse_date(@line[4, 6])
      sign = @line[10, 1] == 'D' ? -1 : 1
      amount = sign * @line[11, 15].gsub(',', '.').to_f
      transaction_type = human_readable_type(@line[27, 3])
      parts = @line.split(/\r?\n/)
      contra_account_iban = parts.size > 1 ? parts.last.gsub(/^[P]{0,1}0*|\t/, '') : nil
      number = contra_account_iban.nil? ? "NONREF" : contra_account_iban.strip.split(//).last(9).join
      @transaction = MT940::Transaction.new(:bank_account => @bank_account,
                                            :bank_account_iban => @bank_account_iban,
                                            amount: amount, bank: @bank,
                                            :currency => @currency,
                                            type: transaction_type,
                                            date: valuta_date,
                                            contra_account_iban: contra_account_iban,
                                            contra_account: number)
    elsif @line.match(/^:61:(\d{6})(C|D)(\d+),(\d{0,2})N(.{3})([P|\d]\d{7,9}|NONREF)\s*(.+)?$/)
      sign = $2 == 'D' ? -1 : 1
      @transaction = MT940::Transaction.new(:bank_account => @bank_account, :amount => sign * ($3 + '.' + $4).to_f, :bank => @bank, :currency => @currency)
      @transaction.type = human_readable_type($5)
      @transaction.date = parse_date($1)
      number = $6.strip
      name = $7 || ""
      number = number.gsub(/\D/, '').gsub(/^0+/, '') unless number == 'NONREF'
      @transaction.contra_account = number
      @transaction.contra_account_owner = name.strip
    else
      raise @line
    end
    @bank_statement.transactions << @transaction
  end

  def parse_tag_86
    if @is_structured_format
      description_parts = @line[4..-1].gsub(/\r|\n|\t/, '').split('/')
      @transaction.contra_account_bic   = description_part_for(description_parts, start: 'ACCW').split(',')[1]
      @transaction.contra_account_owner = description_part_for(description_parts, start: 'NAME', end: 'REMI')
      @transaction.description          = description_part_for(description_parts, start: 'REMI', end: 'ISDT', greedy: true)
    elsif @line.match(/^:86:(.*)$/)
      @transaction.description = [@transaction.description, $1].join(" ").strip
    end
  end

  def mt_940_start_line?(line)
    line.match /^:\d{2}(\D?|\d?):.*$/
  end

  private

  def description_part_for(description_parts, params)
    start_inset_index = description_parts.find_index(params[:start])
    return '' unless start_inset_index
    start_index = start_inset_index + 1
    end_index = params[:end] && (end_inset_index = description_parts.find_index(params[:end])) && (end_inset_index - 1)
    end_index ||= params[:greedy] ? -1 : start_index
    description_parts[start_index..end_index].join('/')
  end

  def human_readable_type(type)
    if type.match(/\d+/)
      MAPPING[type.to_i] || type.to_s
    elsif type == "MSC"
      "MSC"
    else
      type.to_s
    end
  end

  #PAYMENT_TYPES MUT.TXT: {"AC" => "Acceptgiro", "BA" => "Betaalautomaat", "BG" => "Bankgiro", "BY" => "Bijschrijving", "CB" => "Crediteuren betaling", "CK" => "Chipknip", "DA" => "Diverse afboekingen", "DB" => "Diverse Boekingen", "GA" => "Geldautomaat", "ID" => "Ideal", "KO" => "Kasopname", "MA" => "Machtiging", "OV" => "Overschrijving", "PB" => "Periodieke betaling", "TB" => "Telebankieren", "TG" => "Telegiro"}

  #popular types: "MSC", "013", "023", "030", "034", "060", "062", "070", "071", "084", "088", "093", "102", "121", "122", "127", "131", "133", "404", "411", "501", "504", "505", "508", "541", "544", "578", "689", "690", "691"

  SIMPLE_MAPPING = {}
  SIMPLE_MAPPING[13] = "Betaalautomaat"
  SIMPLE_MAPPING[23] = "Geldautomaat"
  SIMPLE_MAPPING[30] = "Betaalautomaat"
  SIMPLE_MAPPING[34] = "Internetbankieren"
  SIMPLE_MAPPING[60] = "Machtiging"
  SIMPLE_MAPPING[62] = "Machtiging"
  SIMPLE_MAPPING[70] = "Machtiging"
  SIMPLE_MAPPING[71] = "Internetbankieren"
  SIMPLE_MAPPING[84] = "Internetbankieren"
  SIMPLE_MAPPING[88] = "Internetbankieren"
  SIMPLE_MAPPING[93] = "Rente"
  SIMPLE_MAPPING[102] = "Ideal"
  SIMPLE_MAPPING[121] = "Pinbetaling"
  SIMPLE_MAPPING[122] = "Crediteurenbetaling"
  SIMPLE_MAPPING[127] = "Betaalopdracht"
  SIMPLE_MAPPING[131] = "Bijschrijving"
  SIMPLE_MAPPING[133] = "Bijschrijving"
  SIMPLE_MAPPING[404] = "Bijschrijving"
  SIMPLE_MAPPING[411] = "Bijschrijving"

  MAPPING = {}
  MAPPING[1]="Betaalopdracht NotaBox"
  MAPPING[10]="Opname bij andere Rabobank"
  MAPPING[11]="Opname balie"
  MAPPING[12]="Betaalautomaat buitenland (vreemde valuta)"
  MAPPING[13]="Betaalautomaat buitenland (euro)"
  MAPPING[14]="Intra Rabo saldoconcentratie (uitgaand)"
  MAPPING[15]="Telefonische machtiging eenmalig"
  MAPPING[16]="Telefonische machtiging doorlopend"
  MAPPING[17]="Telefonische machtiging kansspelen"
  MAPPING[18]="Betaalopdracht Mobiel Bankieren (periodiek)"
  MAPPING[20]="Geldautomaat eigen Rabobank"
  MAPPING[21]="Geldautomaat andere Rabobank"
  MAPPING[22]="Opladen Chipknip"
  MAPPING[23]="Geldautomaat niet Rabobank"
  MAPPING[25]="Acceptgiro Telebankieren"
  MAPPING[26]="Betaalopdracht periodiek restsparen"
  MAPPING[28]="RGS transactie (debet)"
  MAPPING[29]="Geldautomaat buitenland (euro)"
  MAPPING[30]="Betaalautomaat Nederland"
  MAPPING[31]="Geldautomaat buitenland (vreemde valuta)"
  MAPPING[32]="CrediteurenbetalingTelebankieren (periodiek)"
  MAPPING[33]="Betaalopdracht handmatig"
  MAPPING[34]="Betaalopdracht Internetbankieren (periodiek)"
  MAPPING[35]="Betaalopdracht Telebankieren"
  MAPPING[36]="Betaalopdracht Telebankieren (periodiek)"
  MAPPING[37]="Afschrijving overig"
  MAPPING[38]="Crediteurenbetaling Telebankieren"
  MAPPING[39]="Salarisbetaling Telebankieren (periodiek)"
  MAPPING[40]="Betaalopdracht periodiek"
  MAPPING[41]="Acceptgiro bijlageloos"
  MAPPING[42]="Boeking naar consumptief krediet (via bank)"
  MAPPING[44]="Terugboeking incasso"
  MAPPING[45]="Overheidsvordering"
  MAPPING[46]="Terugboeking overheidsvordering"
  MAPPING[47]="Terugboeking machtiging"
  MAPPING[48]="Betaalopdracht Rabobank"
  MAPPING[51]="Betaalopdracht Rabofoon (periodiek)"
  MAPPING[52]="Crediteurenbetaling (Secure FTP)"
  MAPPING[53]="Salarisbetaling Telebankieren"
  MAPPING[57]="Salarisbetaling (Secure FTP)"
  MAPPING[58]="Boeking naar consumptief krediet (balie)"
  MAPPING[59]="Overboeking naar niet Raborekening (balie)"
  MAPPING[60]="Doorlopende machtiging algemeen"
  MAPPING[61]="Eenmalige machtiging"
  MAPPING[62]="Doorlopende machtiging bedrijven"
  MAPPING[63]="Doorlopende machtiging kansspelen"
  MAPPING[64]="Eenmalige actiemachtiging"
  MAPPING[65]="Direct Debit"
  MAPPING[66]="Incasso Sociaal Fonds Bouwnijverh."
  MAPPING[67]="Veilingincasso (geen terugboeking)"
  MAPPING[68]="Salarisbetaling (Internet Services)"
  MAPPING[69]="Crediteurenbetaling (Internet Services)"
  MAPPING[70]="Machtiging Rabobank"
  MAPPING[71]="Betaalopdracht Internetbankieren"
  MAPPING[72]="Betaalopdracht Rabofoon"
  MAPPING[73]="Overboeking naar niet Raborekening (via bank)"
  MAPPING[76]="Betaalopdracht GSM"
  MAPPING[81]="Acceptgiro Mobiel Bankieren"
  MAPPING[82]="Acceptgiro Rabofoon"
  MAPPING[84]="Acceptgiro Internetbankieren"
  MAPPING[88]="Betaalopdracht Mobiel Bankieren"
  MAPPING[90]="Overboeking naar spaarrekening"
  MAPPING[91]="Overboeking naar lening"
  MAPPING[92]="Afschrijving effectenhandeling"
  MAPPING[93]="Afschrijving rente provisie kosten"
  MAPPING[96]="Kastransactie kasrekening (storten)"
  MAPPING[97]="Diverse mutaties debet RN"
  MAPPING[99]="Diverse mutaties debet"
  MAPPING[100]="Bijschrijving iDEAL (Rabo-Rabo)"
  MAPPING[101]="Bijschrijving NotaBox (Rabo-Rabo)"
  MAPPING[102]="Betaalopdracht iDEAL"
  MAPPING[103]="Bijschrijving iDEAL (interbancair)"
  MAPPING[104]="Stortingsapparaat"
  MAPPING[105]="Bijschrijving NotaBox (via Equens)"
  MAPPING[109]="Uitkering WSF"
  MAPPING[110]="Terugboeking DD opdracht bank"
  MAPPING[111]="Terugboeking DD opdracht klant"
  MAPPING[112]="Terugboeking DD opdracht incassant"
  MAPPING[114]="Stortingsapparaat (derden storting)"
  MAPPING[117]="Bijschrijving Maestro betalingen"
  MAPPING[118]="Bijschrijving Vpay betalingen"
  MAPPING[119]="Stortingsapparaat (eigen storting)"
  MAPPING[120]="Bijschrijving PIN betalingen (BEAtel)"
  MAPPING[121]="Bijschrijving PIN betalingen (Datanet)"
  MAPPING[122]="Bijschrijving crediteurenbetaling"
  MAPPING[123]="Bijschrijving acceptgiro"
  MAPPING[125]="Bijschrijving CHIPknip betalingen"
  MAPPING[126]="Bijschrijving salarisbetaling"
  MAPPING[127]="Bijschrijving betaalopdracht"
  MAPPING[128]="Intra Rabo saldoconcentratie (inkomend)"
  MAPPING[129]="Bijschrijving saldo Chipknip"
  MAPPING[130]="Bijschrijving betaalopdracht (periodiek)"
  MAPPING[131]="Bijschrijving CT betaling"
  MAPPING[132]="Terugboeking CT betaling"
  MAPPING[133]="Bijschrijving spoedopdracht"
  MAPPING[134]="Bankmelding spoedopdracht"
  MAPPING[135]="RN physical pooling"
  MAPPING[136]="Overboeking van consumptief krediet (Internetbankieren)"
  MAPPING[137]="Overboeking van consumptief krediet (Rabofoon)"
  MAPPING[139]="Overboeking van consumptief krediet (Mobiel Bankieren)"
  MAPPING[141]="RGS transactie (credit)"
  MAPPING[142]="Baliestorting EUR <3.000"
  MAPPING[143]="Baliestorting EUR 3.000-7.500"
  MAPPING[144]="Baliestorting EUR 7.500-12.000"
  MAPPING[145]="Baliestorting EUR >12.000"
  MAPPING[146]="Baliestorting (filiaal) EUR <3.000"
  MAPPING[147]="Baliestorting (filiaal) EUR 3.000-7.500"
  MAPPING[148]="Baliestorting (filiaal) EUR 7.500-12.000"
  MAPPING[149]="Baliestorting (filiaal) EUR >12.000"
  MAPPING[150]="Spoedopdracht (binnen Rabobank)"
  MAPPING[151]="Spoedopdracht (buiten Rabobank)"
  MAPPING[152]="Spoedopdracht Telebankieren Extra (binnen Rabobank)"
  MAPPING[153]="Spoedopdracht Telebankieren Extra (buiten Rabobank)"
  MAPPING[154]="Spoedopdracht Internetbankieren (buiten Rabobank)"
  MAPPING[155]="Spoedopdracht Internetbankieren (binnen Rabobank)"
  MAPPING[156]="Spoedopdracht balie (buiten Rabobank)"
  MAPPING[157]="Spoedopdracht via bank (buiten Rabobank)"
  MAPPING[158]="Spoedopdracht balie (binnen Rabobank)"
  MAPPING[159]="Spoedopdracht via bank (binnen Rabobank)"
  MAPPING[160]="Salarisbetaling Internetbankieren (batch)"
  MAPPING[161]="Crediteurenbetaling Internetbankieren (batch)"
  MAPPING[162]="Betaalopdracht Internetbankieren (batch)"
  MAPPING[163]="Salarisbetaling Telebankieren (batch)"
  MAPPING[164]="Crediteurenbetaling Telebankieren (batch)"
  MAPPING[172]="Sealbagstorting kwaliteit EUR <3.000"
  MAPPING[173]="Sealbagstorting kwaliteit EUR 3.000-7.500"
  MAPPING[174]="Sealbagstorting kwaliteit EUR 7.500-12.000"
  MAPPING[175]="Sealbagstorting kwaliteit EUR >12.000"
  MAPPING[176]="Sealbagstorting kwaliteit (filiaal) EUR <3.000"
  MAPPING[177]="Sealbagstorting kwaliteit (filiaal) EUR 3.000-7.500"
  MAPPING[178]="Sealbagstorting kwaliteit (filiaal) EUR 7.500-12.000"
  MAPPING[179]="Sealbagstorting kwaliteit (filiaal) EUR >12.000"
  MAPPING[182]="Sealbagstorting non-kwaliteit EUR <3.000"
  MAPPING[183]="Sealbagstorting non-kwaliteit EUR 3.000-7.500"
  MAPPING[184]="Sealbagstorting non-kwaliteit EUR 7.500-12.000"
  MAPPING[185]="Sealbagstorting non-kwaliteit EUR >12.000"
  MAPPING[186]="Sealbagstorting non-kwaliteit (filiaal) EUR <3.000"
  MAPPING[187]="Sealbagstorting non-kwaliteit (filiaal) EUR 3.000-7.500"
  MAPPING[188]="Sealbagstorting non-kwaliteit (filiaal) EUR 7.500-12.000"
  MAPPING[189]="Sealbagstorting non-kwaliteit (filiaal) EUR >12.000"
  MAPPING[190]="Overboeking van spaarrekening"
  MAPPING[191]="Overboeking van lening"
  MAPPING[192]="Bijschrijving effectenhandeling"
  MAPPING[193]="Bijschrijving rente provisie kosten"
  MAPPING[196]="Kastransactie kasrekening (opnemen)"
  MAPPING[197]="Diverse mutaties credit RN"
  MAPPING[199]="Diverse mutaties credit"
  MAPPING[201]="Telebankieren vrijgeven opdrachten"
  MAPPING[204]="Stortingsapparaat biljetten (eigen storting)"
  MAPPING[205]="MT101-berichten"
  MAPPING[206]="Batch incasso (Telebankieren)"
  MAPPING[207]="Telebankieren sessiekosten"
  MAPPING[208]="Telebankieren Extra informatie kosten boeksaldi"
  MAPPING[209]="Telebankieren Extra informatie kosten valutaire saldi"
  MAPPING[214]="Batch betalen (Secure FTP)"
  MAPPING[215]="Batch betalen (Internet Services)"
  MAPPING[216]="Batch PIN bijschrijvingen"
  MAPPING[217]="Batch CHIPknip bijschrijvingen"
  MAPPING[224]="Batch incasso (Secure FTP)"
  MAPPING[225]="Batch incasso (Internet Services)"
  MAPPING[230]="Contante valutatransactie EUR~VV EUR <50.000"
  MAPPING[231]="Contante valutatransactie EUR~VV EUR 50.000-100.000"
  MAPPING[232]="Contante valutatransactie EUR~VV EUR 100.000-150.000"
  MAPPING[233]="Contante valutatransactie EUR~VV EUR >150.000"
  MAPPING[234]="Valutatermijntransactie EUR~VV EUR <100.000"
  MAPPING[235]="Valutatermijntransactie EUR~VV EUR 100.000-225.000"
  MAPPING[236]="Valutatermijntransactie EUR~VV EUR 225.000-450.000"
  MAPPING[237]="Valutatermijntransactie EUR~VV EUR 450.000-1.000.000"
  MAPPING[238]="Valutatermijntransactie EUR~VV EUR 1.000.000-4.500.000"
  MAPPING[239]="Valutatermijntransactie EUR~VV EUR >4.500.000"
  MAPPING[240]="Valutaswaptransactie EUR~VV EUR <100.000"
  MAPPING[241]="Valutaswaptransactie EUR~VV EUR 100.000-225.000"
  MAPPING[242]="Valutaswaptransactie EUR~VV EUR 225.000-450.000"
  MAPPING[243]="Valutaswaptransactie EUR~VV EUR 450.000-1.000.000"
  MAPPING[244]="Valutaswaptransactie EUR~VV EUR 1.000.000-4.500.000"
  MAPPING[245]="Valutaswaptransactie EUR~VV EUR >4.500.000"
  MAPPING[246]="Valutaswaptransactie EUR~VV laatste transactie"
  MAPPING[247]="Contante valutatransactie VV~EUR EUR <50.000"
  MAPPING[248]="Contante valutatransactie VV~EUR EUR 50.000-100.000"
  MAPPING[249]="Contante valutatransactie VV~EUR EUR 100.000-150.000"
  MAPPING[250]="Contante valutatransactie VV~EUR EUR >150.000"
  MAPPING[251]="Valutatermijntransactie VV~EUR EUR <100.000"
  MAPPING[252]="Valutatermijntransactie VV~EUR EUR 100.000-225.000"
  MAPPING[253]="Valutatermijntransactie VV~EUR EUR 225.000-450.000"
  MAPPING[254]="Valutatermijntransactie VV~EUR EUR 450.000-1.000.000"
  MAPPING[255]="Valutatermijntransactie VV~EUR EUR 1.000.000-4.500.000"
  MAPPING[256]="Valutatermijntransactie VV~EUR EUR >4.500.000"
  MAPPING[257]="Valutaswaptransactie VV~EUR EUR <100.000"
  MAPPING[258]="Valutaswaptransactie VV~EUR EUR 100.000-225.000"
  MAPPING[259]="Valutaswaptransactie VV~EUR EUR 225.000-450.000"
  MAPPING[260]="Valutaswaptransactie VV~EUR EUR 450.000-1.000.000"
  MAPPING[261]="Valutaswaptransactie VV~EUR EUR 1.000.000-4.500.000"
  MAPPING[262]="Valutaswaptransactie VV~EUR EUR >4.500.000"
  MAPPING[263]="Valutaswaptransactie VV~EUR laatste transactie"
  MAPPING[269]="Niet leverbare termijnaffaire"
  MAPPING[270]="Contante valutatransactie VV~VV EUR <50.000"
  MAPPING[271]="Contante valutatransactie VV~VV EUR 50.000-100.000"
  MAPPING[272]="Contante valutatransactie VV~VV EUR 100.000-150.000"
  MAPPING[273]="Contante valutatransactie VV~VV EUR >150.000"
  MAPPING[274]="Valutatermijntransactie VV~VV EUR <100.000"
  MAPPING[275]="Valutatermijntransactie VV~VV EUR 100.000-225.000"
  MAPPING[276]="Valutatermijntransactie VV~VV EUR 225.000-450.000"
  MAPPING[277]="Valutatermijntransactie VV~VV EUR 450.000-1.000.000"
  MAPPING[278]="Valutatermijntransactie VV~VV EUR 1.000.000-4.500.000"
  MAPPING[279]="Valutatermijntransactie VV~VV EUR >4.500.000"
  MAPPING[280]="Valutaswaptransactie VV~VV EUR <100.000"
  MAPPING[281]="Valutaswaptransactie VV~VV EUR 100.000-225.000"
  MAPPING[282]="Valutaswaptransactie VV~VV EUR 225.000-450.000"
  MAPPING[283]="Valutaswaptransactie VV~VV EUR 450.000-1.000.000"
  MAPPING[284]="Valutaswaptransactie VV~VV EUR 1.000.000-4.500.000"
  MAPPING[285]="Valutaswaptransactie VV~VV EUR >4.500.000"
  MAPPING[286]="Valutaswaptransactie VV~VV laatste transactie"
  MAPPING[287]="Rabo iDEAL Professional entree"
  MAPPING[288]="Rabo iDEAL Professional abonnement"
  MAPPING[289]="Rabo iDEAL Kassa entree"
  MAPPING[290]="Rabo iDEAL Kassa abonnement"
  MAPPING[291]="Rabo iDEAL Kassa transactie"
  MAPPING[292]="MiniTix-optie abonnement"
  MAPPING[293]="Logo-optie"
  MAPPING[294]="Overstap naar Rabo Internetkassa"
  MAPPING[295]="Rabo Internetkassa entree"
  MAPPING[296]="Rabo Internetkassa abonnement"
  MAPPING[297]="Rabo Internetkassa transactie"
  MAPPING[298]="Callcenter-optie entree"
  MAPPING[299]="Callcenter-optie abonnement"
  MAPPING[300]="Overstapservice"
  MAPPING[301]="Rekeningafschrift papier"
  MAPPING[302]="Rekeningafschrift braille"
  MAPPING[303]="Mededeling niet uitgevoerde periodieke opdracht"
  MAPPING[304]="Rekeningafschrift (extra exemplaar)"
  MAPPING[305]="Rekeningafschrift VV rekening"
  MAPPING[306]="Mededeling"
  MAPPING[307]="Overzicht mutaties"
  MAPPING[308]="Overzicht mutaties braille"
  MAPPING[309]="Rekeningafschrift digitaal"
  MAPPING[310]="Rekeningafschrift niet aangemaakt"
  MAPPING[311]="Overzicht mutaties via bank"
  MAPPING[312]="Rekeningafschrift (kopie)"
  MAPPING[313]="Mededeling digitaal afschrift"
  MAPPING[314]="Terugboeking actieaanbod digitaal rekeningafschrift"
  MAPPING[315]="Maandelijks rekeningoverzicht"
  MAPPING[316]="Nota rente, provisie en kosten "
  MAPPING[317]="Nota rente, provisie en kosten samenstelling"
  MAPPING[318]="Staffel"
  MAPPING[319]="Specificatie bij nota"
  MAPPING[320]="Boekje overschrijvingsformulieren"
  MAPPING[321]="Specificatie bij rekeningafschrift"
  MAPPING[322]="Opdrachtformulieren"
  MAPPING[323]="Maandelijks portefeuille-overzicht"
  MAPPING[324]="URLinked 2 Homepage entree"
  MAPPING[325]="URLinked 2 Homepage klik"
  MAPPING[326]="Bericht van rentewijziging credit"
  MAPPING[327]="Bericht van rentewijziging debet"
  MAPPING[328]="URLinked 2 Personalinfo entree"
  MAPPING[329]="URLinked 2 Personalinfo klik"
  MAPPING[330]="ERI informatierecords"
  MAPPING[332]="BRI abonnement"
  MAPPING[333]="BRI download"
  MAPPING[334]="BRI informatierecord"
  MAPPING[341]="ERI filetransfer"
  MAPPING[342]="VerwInfo entree"
  MAPPING[343]="VerwInfo abonnement"
  MAPPING[344]="VerwInfo geleverde batches"
  MAPPING[345]="VerwInfo geleverde posten"
  MAPPING[350]="Abonnement PIN/COMBI automaat koop (vast)"
  MAPPING[351]="Abonnement PIN/COMBI automaat koop (mobiel)"
  MAPPING[352]="Abonnement PIN/COMBI automaat huur (vast)"
  MAPPING[353]="Abonnement PIN/COMBI automaat huur (mobiel)"
  MAPPING[360]="Aanmaak/heraanmaak Rabopas"
  MAPPING[361]="Aanmaak/heraanmaak pincode Rabopas"
  MAPPING[362]="Behandeling reclame"
  MAPPING[363]="Stickers afstortformulier"
  MAPPING[370]="Telebankieren informatie kosten <10.000 mutaties"
  MAPPING[371]="Telebankieren informatie kosten 10.000-50.000 mutaties"
  MAPPING[372]="Telebankieren informatie kosten >50.000 mutaties"
  MAPPING[374]="Telebankieren vrijgeven opdrachten SMS-bericht"
  MAPPING[375]="Telebankieren vrijgeven opdrachten e-mail"
  MAPPING[376]="NotaBox Alerts sms"
  MAPPING[377]="NotaBox Alerts e-mail"
  MAPPING[378]="NotaBox Alerts abonnement"
  MAPPING[380]="Rabo Mobiel Saldo e-mail"
  MAPPING[381]="Rabo Roodstand Alerts"
  MAPPING[382]="Rabo Saldo SMS"
  MAPPING[383]="Rabo Mobiel Saldo SMS (leden)"
  MAPPING[384]="Rabo Mobiel Saldochecker"
  MAPPING[387]="Rabo iDEAL Lite entree"
  MAPPING[388]="Rabo iDEAL Professional PSP abonnement"
  MAPPING[389]="Rabo iDEAL Lite abonnement"
  MAPPING[390]="Rabo Cashflow Forecasting Module entree"
  MAPPING[391]="Rabo Cashflow Forecasting Module abonnement"
  MAPPING[392]="Rabo Cash Management entree"
  MAPPING[393]="Rabo Cash Management abonnement"
  MAPPING[394]="Rabo Cash Management alerts"
  MAPPING[395]="RFLP extra toegangspas"
  MAPPING[396]="RFLP extra paslezer"
  MAPPING[397]="RFLP informatiekosten (per record)"
  MAPPING[398]="RFLP downloadkosten (per record)"
  MAPPING[400]="Acceptgiro RFLP"
  MAPPING[401]="Crediteurenbetaling RFLP"
  MAPPING[402]="Crediteurenbetaling RFLP (periodiek)"
  MAPPING[403]="Crediteurenbetaling RFLP (batch)"
  MAPPING[404]="Buitenland transactie (credit)"
  MAPPING[405]="Salarisbetaling RFLP (periodiek)"
  MAPPING[406]="Salarisbetaling RFLP (batch)"
  MAPPING[407]="Betaalopdracht RFLP"
  MAPPING[408]="Betaalopdracht RFLP (periodiek)"
  MAPPING[409]="Spoedopdracht RFLP (binnen Rabobank)"
  MAPPING[410]="Spoedopdracht RFLP (buiten Rabobank)"
  MAPPING[411]="Buitenland transactie (debet)"
  MAPPING[412]="Salarisbetaling RFLP"
  MAPPING[421]="Bijboeking buitenland BEN Equens"
  MAPPING[422]="Bijboeking buitenland OUR Equens"
  MAPPING[423]="Bijboeking buitenland SHA Equens"
  MAPPING[424]="Bijschrijving EuroPlus SHA"
  MAPPING[425]="Bijschrijving EuroPlus OUR"
  MAPPING[426]="Bijschrijving EuroPlus BEN"
  MAPPING[427]="Bijschrijving EuroPlus SHA spoed"
  MAPPING[428]="Bijschrijving EuroPlus OUR spoed"
  MAPPING[429]="Bijschrijving EuroPlus BEN spoed"
  MAPPING[430]="Physical pooling sweep funding"
  MAPPING[431]="Physical pooling sweep skimming"
  MAPPING[432]="Overnight pooling forward sweep debet"
  MAPPING[433]="Overnight pooling forward sweep credit"
  MAPPING[434]="Overnight pooling back sweep debet"
  MAPPING[435]="Overnight pooling back sweep credit"
  MAPPING[439]="Bankcheque post"
  MAPPING[449]="Bankcheque post handmatig"
  MAPPING[450]="ICM BOA Lockbox Verenigd Koninkrijk"
  MAPPING[451]="ICM BOA Lockbox Ierland"
  MAPPING[452]="ICM BOA Lockbox Duitsland"
  MAPPING[453]="ICM BOA Lockbox Frankrijk"
  MAPPING[454]="ICM BOA Lockbox Verenigde Staten"
  MAPPING[458]="Bankcheque aangetekend"
  MAPPING[459]="Bankcheque aangetekend handmatig"
  MAPPING[462]="ICM BOA abonnement"
  MAPPING[463]="ICM BOA rekening"
  MAPPING[464]="ICM BOA transactie"
  MAPPING[465]="Buitenland niet grensoverschrijdend"
  MAPPING[466]="Bijschrijving buitenland niet grensoverschrijdend"
  MAPPING[467]="Bijschrijving buitenland niet grensoverschrijdend franco"
  MAPPING[468]="Bankcheque koerier NL"
  MAPPING[469]="Bankcheque koerier NL handmatig"
  MAPPING[470]="ICM aanzuiveren uitgaand"
  MAPPING[471]="ICM afromen inkomend"
  MAPPING[472]="ICM saldo concentratie services afromen inkomend"
  MAPPING[473]="ICM saldo concentratie services aanzuiveren uitgaand"
  MAPPING[474]="ICM aanzuiveren inkomend"
  MAPPING[475]="ICM saldo concentratie services aanzuiveren inkomend"
  MAPPING[476]="ICM saldo concentratie services afromen uitgaand"
  MAPPING[477]="ICM afromen uitgaand"
  MAPPING[478]="Bankcheque koerier buitenland"
  MAPPING[479]="Bankcheque koerier buitenland (handmatig)"
  MAPPING[481]="EuroPlus OUR"
  MAPPING[482]="EuroPlus BEN"
  MAPPING[483]="EuroPlus SHA"
  MAPPING[484]="EuroPlus SHA handmatig"
  MAPPING[485]="EuroPlus OUR handmatig"
  MAPPING[486]="EuroPlus BEN handmatig"
  MAPPING[487]="EuroPlus SHA spoed"
  MAPPING[488]="EuroPlus OUR spoed"
  MAPPING[489]="EuroPlus BEN spoed"
  MAPPING[490]="EuroPlus SHA handmatig spoed"
  MAPPING[491]="EuroPlus OUR handmatig spoed"
  MAPPING[492]="EuroPlus BEN handmatig spoed"
  MAPPING[494]="Eurobetaling SHA"
  MAPPING[495]="Eurobetaling SHA spoed"
  MAPPING[498]="Eurobetaling SHA spoed handmatig"
  MAPPING[501]="Overboeking naar betaalrekening (Internetbankieren)"
  MAPPING[502]="Overboeking naar betaalrekening (Rabofoon)"
  MAPPING[503]="Overboeking naar betaalrekening (Telebankieren)"
  MAPPING[504]="Overboeking naar spaarrekening (Mobiel Bankieren)"
  MAPPING[505]="Overboeking naar spaarrekening (Internetbankieren)"
  MAPPING[506]="Overboeking naar spaarrekening (Rabofoon)"
  MAPPING[507]="Overboeking naar spaarrekening (Telebankieren)"
  MAPPING[508]="Overboeking naar betaalrekening (Mobiel Bankieren)(periodiek)"
  MAPPING[509]="Overboeking naar betaalrekening (Internetbankieren)(periodiek)"
  MAPPING[510]="Overboeking naar betaalrekening (Rabofoon)(periodiek)"
  MAPPING[511]="Overboeking naar spaarrekening (Mobiel Bankieren)(periodiek)"
  MAPPING[512]="Overboeking naar spaarrekening (Internetbankieren)(periodiek)"
  MAPPING[513]="Sealbagstorting kwaliteit EUR basistarief"
  MAPPING[514]="Sealbagstorting kwaliteit EUR coupures"
  MAPPING[517]="Sealbagstorting non-kwaliteit EUR basistarief"
  MAPPING[518]="Sealbagstorting non-kwaliteit EUR coupures"
  MAPPING[523]="Storting munten container"
  MAPPING[525]="Storting munten zakken"
  MAPPING[526]="Storting munten tellen"
  MAPPING[531]="Storting vreemde valuta basistarief"
  MAPPING[532]="Storting vreemde valuta coupures"
  MAPPING[533]="Storting vreemde valuta EUR <3.000"
  MAPPING[534]="Storting vreemde valuta EUR 3.000-7.500"
  MAPPING[535]="Storting vreemde valuta EUR 7.500-12.000"
  MAPPING[536]="Storting vreemde valuta EUR >12.000"
  MAPPING[538]="Overboeking naar spaarrekening (Telebankieren)(periodiek)"
  MAPPING[540]="Bijschrijving Eurobetaling SHA"
  MAPPING[543]="Bijschrijving Eurobetaling SHA spoed"
  MAPPING[552]="Wereldbetaling SHA"
  MAPPING[553]="Wereldbetaling OUR"
  MAPPING[554]="Wereldbetaling BEN"
  MAPPING[555]="Wereldbetaling SHA spoed"
  MAPPING[556]="Wereldbetaling OUR spoed"
  MAPPING[557]="Wereldbetaling BEN spoed"
  MAPPING[558]="Wereldbetaling SHA met instructies"
  MAPPING[559]="Wereldbetaling OUR met instructies"
  MAPPING[560]="Wereldbetaling BEN met instructies"
  MAPPING[561]="Wereldbetaling SHA spoed overige instructies"
  MAPPING[562]="Wereldbetaling OUR spoed overige instructies"
  MAPPING[563]="Wereldbetaling BEN spoed overige instructies"
  MAPPING[565]="Overboeking naar betaalrekening (balie)"
  MAPPING[566]="Overboeking naar spaarrekening (balie)"
  MAPPING[567]="Overboeking naar lening (balie)"
  MAPPING[568]="Overboeking van betaalrekening (balie)"
  MAPPING[569]="Overboeking van spaarrekening (balie)"
  MAPPING[574]="Muntrollen"
  MAPPING[575]="Overboeking van consumptief krediet (balie)"
  MAPPING[576]="Overboeking naar betaalrekening (via bank)"
  MAPPING[577]="Overboeking naar spaarrekening (Rabofoon)(periodiek)"
  MAPPING[578]="Overboeking naar betaalrekening (Mobiel Bankieren)"
  MAPPING[579]="Bestelling biljetten"
  MAPPING[580]="Overboeking naar spaarrekening (via bank)"
  MAPPING[581]="Overboeking naar lening (via bank)"
  MAPPING[582]="Overboeking van betaalrekening (via bank)"
  MAPPING[591]="Stortingsverschil EUR"
  MAPPING[592]="Stortingsverschil VV"
  MAPPING[600]="Rabo BasisPakket met Wereldpas en maandelijks afschrift"
  MAPPING[601]="Rabo BasisPakket met Wereldpas en tweewekelijks afschrift"
  MAPPING[602]="Rabo BasisPakket met Wereldpas en wekelijks afschrift"
  MAPPING[603]="Rabo BasisPakket met Rabopas en maandelijks afschrift"
  MAPPING[604]="Rabo BasisPakket met Rabopas en tweewekelijks afschrift"
  MAPPING[605]="Rabo BasisPakket met Rabopas en wekelijks afschrift"
  MAPPING[606]="Rabo DirectPakket met Wereldpas en maandelijks afschrift"
  MAPPING[607]="Rabo TotaalPakket met Wereldpas en Rabocard en maandelijks afschrift"
  MAPPING[608]="Rabo TotaalPakket met Wereldpas en Rabocard en tweewekelijks afschrift"
  MAPPING[609]="Rabo TotaalPakket met Wereldpas en Rabocard en wekelijks afschrift"
  MAPPING[610]="Rabo RiantPakket met Wereldpas en GoldCard en maandelijks afschrift"
  MAPPING[611]="Rabo RiantPakket met Wereldpas en GoldCard en tweewekelijks afschrift"
  MAPPING[612]="Rabo RiantPakket met Wereldpas en GoldCard en wekelijks afschrift"
  MAPPING[613]="Extra betaalrekening met maandelijks afschrift"
  MAPPING[614]="Extra betaalrekening met tweewekelijks afschrift"
  MAPPING[615]="Extra betaalrekening met wekelijks afschrift"
  MAPPING[640]="Doorlopende machtiging algemeen (Telebankieren)"
  MAPPING[641]="Eenmalige machtiging (Telebankieren)"
  MAPPING[642]="Doorlopende machtiging bedrijven (Telebankieren)"
  MAPPING[643]="Doorlopende machtiging kansspelen (Telebankieren)"
  MAPPING[644]="Eenmalige actiemachtiging (Telebankieren)"
  MAPPING[646]="Incasso Sociaal Fonds Bouwnijverh. (Telebankieren)"
  MAPPING[647]="Veilingincasso (geen terugboeking) (Telebankieren)"
  MAPPING[648]="Telefonische machtiging eenmalig (Telebankieren)"
  MAPPING[649]="Telefonische machtiging doorlopend (Telebankieren)"
  MAPPING[654]="Overboeking van betaalrekening (Telebankieren)(periodiek)"
  MAPPING[655]="Overboeking van betaalrekening (Telebankieren)"
  MAPPING[656]="Overboeking van spaarrekening (Telebankieren)"
  MAPPING[660]="Doorlopende machtiging algemeen (Secure FTP)"
  MAPPING[661]="Eenmalige machtiging (Secure FTP)"
  MAPPING[662]="Doorlopende machtiging bedrijven (Secure FTP)"
  MAPPING[663]="Doorlopende machtiging kansspelen (Secure FTP)"
  MAPPING[664]="Eenmalige actiemachtiging (Secure FTP)"
  MAPPING[666]="Incasso Sociaal Fonds Bouwnijverh. (Secure FTP)"
  MAPPING[667]="Veilingincasso (geen terugboeking) (Secure FTP)"
  MAPPING[668]="Telefonische machtiging eenmalig (Secure FTP)"
  MAPPING[669]="Telefonische machtiging doorlopend (Secure FTP)"
  MAPPING[670]="Doorlopende machtiging algemeen (Internet Services)"
  MAPPING[671]="Eenmalige machtiging (Internet Services)"
  MAPPING[672]="Doorlopende machtiging bedrijven (Internet Services)"
  MAPPING[673]="Doorlopende machtiging kansspelen (Internet Services)"
  MAPPING[674]="Eenmalige actiemachtiging (Internet Services)"
  MAPPING[676]="Incasso Sociaal Fonds Bouwnijverh. (Internet Services)"
  MAPPING[677]="Veilingincasso (geen terugboeking) (Internet Services)"
  MAPPING[678]="Telefonische machtiging eenmalig (Internet Services)"
  MAPPING[679]="Telefonische machtiging doorlopend (Internet Services)"
  MAPPING[684]="Telefonische machtiging kansspelen (Telebankieren)"
  MAPPING[686]="Telefonische machtiging kansspelen (Secure FTP)"
  MAPPING[687]="Telefonische machtiging kansspelen (Internet Services)"
  MAPPING[688]="Overboeking van betaalrekening (Mobiel Bankieren)(periodiek)"
  MAPPING[689]="Overboeking van betaalrekening (Mobiel Bankieren)"
  MAPPING[690]="Overboeking van spaarrekening (Internetbankieren)"
  MAPPING[691]="Overboeking van spaarrekening (Mobiel Bankieren)"
  MAPPING[692]="Overboeking van spaarrekening (via bank)"
  MAPPING[693]="Overboeking van lening (via bank)"
  MAPPING[694]="Overboeking van consumptief krediet (via bank)"
  MAPPING[695]="Overboeking van betaalrekening (Rabofoon)(periodiek)"
  MAPPING[696]="Overboeking van betaalrekening (Rabofoon)"
  MAPPING[697]="Overboeking van spaarrekening (Rabofoon)"
  MAPPING[698]="Overboeking van betaalrekening (Internetbankieren)(periodiek)"
  MAPPING[699]="Overboeking van betaalrekening (Internetbankieren)"
  MAPPING[700]="Machtiging (Rabobank)"
  MAPPING[701]="Storting travellercheques EUR <3.000"
  MAPPING[702]="Storting travellercheques EUR 3.000-7.500"
  MAPPING[703]="Storting travellercheques EUR 7.500-12.000"
  MAPPING[704]="Storting travellercheques EUR >12.000"
  MAPPING[705]="Stortingsverschil travellercheques"
  MAPPING[706]="Bestelling eurobiljetten internet EUR <450"
  MAPPING[707]="Bestelling eurobiljetten internet EUR >450"
  MAPPING[708]="Bestelling vreemde valuta internet EUR <450"
  MAPPING[709]="Bestelling vreemde valuta internet EUR >450"
  MAPPING[710]="WereldBasis SHA"
  MAPPING[711]="Bestelling eurobiljetten EUR <450"
  MAPPING[712]="Bestelling eurobiljetten EUR 450-5.000"
  MAPPING[713]="Bestelling eurobiljetten EUR 5.000-25.000"
  MAPPING[714]="Bestelling eurobiljetten EUR >25.000"
  MAPPING[716]="WereldBasis BEN"
  MAPPING[717]="WereldBasis SHA handmatig"
  MAPPING[719]="Bestelling vreemde valuta EUR <450"
  MAPPING[720]="Bestelling vreemde valuta EUR 450-5.000"
  MAPPING[721]="Bestelling vreemde valuta EUR 5.000-25.000"
  MAPPING[722]="Bestelling vreemde valuta EUR >25.000"
  MAPPING[723]="WereldBasis BEN handmatig"
  MAPPING[724]="WereldBasis SHA spoed"
  MAPPING[725]="WereldBasis SP SHA"
  MAPPING[726]="WereldBasis SP BEN"
  MAPPING[727]="WereldBasis SP SHA handmatig"
  MAPPING[728]="WereldBasis SP BEN handmatig"
  MAPPING[729]="WereldBasis SP SHA spoed"
  MAPPING[730]="WereldBasis BEN spoed"
  MAPPING[731]="WereldBasis SHA handmatig spoed"
  MAPPING[732]="WereldBasis SP BEN spoed"
  MAPPING[733]="WereldBasis SP SHA handmatig spoed"
  MAPPING[734]="WereldBasis SP BEN handmatig spoed"
  MAPPING[735]="WereldBasis SP OUR"
  MAPPING[736]="WereldBasis SP OUR handmatig"
  MAPPING[737]="WereldBasis BEN handmatig spoed"
  MAPPING[738]="WereldPlus SHA"
  MAPPING[739]="WereldBasis SP OUR spoed"
  MAPPING[740]="WereldBasis SP OUR handmatig spoed"
  MAPPING[744]="WereldPlus BEN"
  MAPPING[745]="WereldPlus SHA handmatig"
  MAPPING[751]="WereldPlus BEN handmatig"
  MAPPING[752]="WereldPlus SHA spoed"
  MAPPING[758]="WereldPlus BEN spoed"
  MAPPING[759]="WereldPlus SHA handmatig spoed"
  MAPPING[765]="WereldPlus BEN handmatig spoed"
  MAPPING[766]="WereldPlus SHA overige instructies"
  MAPPING[772]="WereldPlus BEN overige instructies"
  MAPPING[773]="WereldPlus SHA handmatig overige instructies"
  MAPPING[779]="WereldPlus BEN handmatig overige instructies"
  MAPPING[780]="WereldPlus SHA spoed overige instructies"
  MAPPING[786]="WereldPlus BEN spoed overige instructies"
  MAPPING[787]="WereldPlus SHA handmatig spoed overige instructies"
  MAPPING[793]="WereldPlus BEN handmatig spoed overige instructies"
  MAPPING[800]="MiniTix entree"
  MAPPING[801]="MiniTix loyalty uitgegeven punt"
  MAPPING[802]="MiniTix loyalty betaling"
  MAPPING[811]="Transactie MiniTix 1"
  MAPPING[812]="Transactie MiniTix 2"
  MAPPING[813]="Transactie MiniTix 3"
  MAPPING[814]="Transactie MiniTix 4"
  MAPPING[815]="Transactie MiniTix 5"
  MAPPING[816]="Transactie MiniTix 6"
  MAPPING[817]="Transactie MiniTix 7"
  MAPPING[818]="Transactie MiniTix 8"
  MAPPING[819]="Transactie MiniTix 9"
  MAPPING[820]="Transactie MiniTix 10"
  MAPPING[821]="Transactie MiniTix 11"
  MAPPING[822]="Transactie MiniTix 12"
  MAPPING[823]="Transactie MiniTix 13"
  MAPPING[824]="Transactie MiniTix 14"
  MAPPING[830]="Prepaid -1"
  MAPPING[831]="Prepaid -2"
  MAPPING[832]="Prepaid -3"
  MAPPING[833]="Prepaid -4"
  MAPPING[834]="Prepaid -5"
  MAPPING[835]="Prepaid -6"
  MAPPING[836]="Prepaid -7"
  MAPPING[837]="Prepaid -8"
  MAPPING[838]="Prepaid -9"
  MAPPING[839]="Prepaid -10"
  MAPPING[840]="Prepaid -11"
  MAPPING[841]="Prepaid -12"
  MAPPING[842]="Prepaid -13"
  MAPPING[843]="Prepaid -14"
  MAPPING[844]="Prepaid -15"
  MAPPING[845]="Prepaid -16"
  MAPPING[846]="Prepaid -17"
  MAPPING[847]="Prepaid -18"
  MAPPING[848]="Prepaid -19"
  MAPPING[849]="Prepaid -20"
  MAPPING[850]="Prepaid -21"
  MAPPING[851]="Prepaid -22"
  MAPPING[852]="Prepaid -23"
  MAPPING[853]="Prepaid -24"
  MAPPING[854]="Prepaid -25"
  MAPPING[860]="Ingeleverde batch met cheques"
  MAPPING[861]="Debitering buitenlandcheque"
  MAPPING[862]="Creditering OGV cheque"
  MAPPING[863]="Creditering incasso cheque"
  MAPPING[864]="Creditering Quick cheque"
  MAPPING[865]="Cheque op onze kas"
  MAPPING[866]="Cheque onbetaald retour"
  MAPPING[867]="Stoppayment bankcheque"
  MAPPING[868]="Stoppayment particuliere cheque"
  MAPPING[869]="Cheque op handelsbanken"
  MAPPING[870]="WereldBasis OUR"
  MAPPING[871]="WereldBasis OUR handmatig"
  MAPPING[872]="WereldBasis OUR spoed"
  MAPPING[873]="WereldBasis OUR handmatig spoed"
  MAPPING[874]="WereldPlus OUR"
  MAPPING[875]="WereldPlus OUR handmatig"
  MAPPING[876]="WereldPlus OUR spoed"
  MAPPING[877]="WereldPlus OUR handmatig spoed"
  MAPPING[878]="WereldPlus OUR overige instructies"
  MAPPING[879]="WereldPlus OUR handmatig overige instructies"
  MAPPING[880]="WereldPlus OUR spoed overige instructies"
  MAPPING[881]="WereldPlus OUR handmatig spoed overige instructies"
  MAPPING[883]="Eurobetaling SHA handmatig"
  MAPPING[884]="Eurobetaling BEN handmatig"
  MAPPING[885]="Internetbankieren pro printopdracht"
  MAPPING[886]="Internetbankieren pro iDEAL downloaden"
  MAPPING[887]="Internetbankieren iDEAL downloaden"
  MAPPING[888]="Internetbankieren pro iDEAL transactie informatie"
  MAPPING[889]="Internetbankieren iDEAL transactie informatie"
  MAPPING[890]="Internetbankieren pro downloaden"
  MAPPING[891]="Internetbankieren pro raadplegen"
  MAPPING[892]="Internetbankieren pro transactie informatie"
  MAPPING[893]="Internetbankieren transactie informatie"
  MAPPING[894]="MT942-berichten abonnement"
  MAPPING[895]="MT942-berichten"
  MAPPING[896]="Cashpool abonnement VV"
  MAPPING[897]="Cashpool abonnement"
  MAPPING[900]="Rabox"
  MAPPING[901]="Telebankieren Extra abonnement"
  MAPPING[902]="Telebankieren Extra entree"
  MAPPING[903]="Telebankieren Extra pas"
  MAPPING[904]="Telebankieren Extra abonnement buitenland"
  MAPPING[905]="Telebankieren Extra entree buitenland"
  MAPPING[908]="Telebankieren Extra entree incasso"
  MAPPING[910]="Entree multibank"
  MAPPING[911]="Telebankieren Extra entree rekeningbeheer"
  MAPPING[912]="Telebankieren Extra entree autorisatie"
  MAPPING[913]="Doorleveren rekeninginformatie voor ICM (SWIFT)"
  MAPPING[914]="Telebankieren vrijgeven opdrachten entree"
  MAPPING[915]="Abonnement multibank"
  MAPPING[916]="Telebankieren Extra abonnement rekeningbeheer"
  MAPPING[917]="Telebankieren Extra abonnement autorisatie"
  MAPPING[918]="Telebankieren vrijgeven opdrachten abonnement"
  MAPPING[919]="Rabo Alerts abonnement"
  MAPPING[920]="Internetbankieren abonnement"
  MAPPING[922]="Rabo Alerts e-mail"
  MAPPING[923]="Rabo Alerts SMS"
  MAPPING[924]="Rabo Mobiel Alerts e-mail"
  MAPPING[925]="Rabo Bijschrijving Alerts"
  MAPPING[926]="Rabo MobielBankieren abonnement"
  MAPPING[927]="Abonnement Internet Services"
  MAPPING[928]="Abonnement PIN/COMBI automaat (vast)"
  MAPPING[929]="Abonnement CHIP-only automaat"
  MAPPING[930]="Ombuiging bankgiro naar acceptgiro"
  MAPPING[931]="Rekeninginformatie Rabo Swift entree"
  MAPPING[933]="Rabo Mobiel abonnement"
  MAPPING[934]="Internetbankieren downloaden"
  MAPPING[935]="Rabo Mobiel Alerts abonnement"
  MAPPING[936]="Rabo Mobiel Alerts SMS"
  MAPPING[937]="Rabofoon bedrijven informatiekosten"
  MAPPING[938]="Internetbankieren raadplegen"
  MAPPING[939]="Rabo Mobiel Alerts SMS (leden)"
  MAPPING[940]="Intra Rabo Cash Concentration (dagelijks)"
  MAPPING[941]="Automatische Cash Concentration (dagelijks)"
  MAPPING[942]="Automatische Cash Concentration (wekelijks)"
  MAPPING[943]="Automatische Cash Concentration (maandelijks)"
  MAPPING[944]="Abonnement PIN/COMBI automaat (mobiel)"
  MAPPING[950]="Donatie van uw Rabobank Internetbankieren abonnement"
  MAPPING[951]="Donatie van uw Rabobank (extra) Rekening-Courant"
  MAPPING[952]="PIN betalingen Convenantkorting"
  MAPPING[959]="Saldocompensatie"
  MAPPING[960]="Beheerskosten"
  MAPPING[961]="G-rekening"
  MAPPING[962]="Samenstelling"
  MAPPING[963]="Vreemde valuta rekening"
  MAPPING[964]="Afsluitkosten Rabo Flex Krediet"
  MAPPING[965]="Opening Rabo BetaalPakket"
  MAPPING[966]="Opening Rabo BasisRekening"
  MAPPING[967]="Rabo RiantPakket"
  MAPPING[968]="Rabo RiantPakket met Rabocard"
  MAPPING[969]="Rabo RiantPakket met Rabo GoldCard"
  MAPPING[970]="Interhelp Extra"
  MAPPING[974]="Rabo Ondernemers Pakket met startersvoordeel"
  MAPPING[975]="Rekening-Courant"
  MAPPING[976]="Extra Rekening-Courant"
  MAPPING[977]="Rabo VerenigingsPakket"
  MAPPING[978]="StudentenPakket"
  MAPPING[979]="Rabo VerenigingsRekening"
  MAPPING[980]="Betaalrekening"
  MAPPING[981]="Betaalrekening met Europas"
  MAPPING[982]="StudentenPakket met Rabocard"
  MAPPING[984]="Rabo BasisRekening"
  MAPPING[985]="Rabo BetaalPakket"
  MAPPING[986]="Rabo TotaalPakket"
  MAPPING[987]="Rabo TotaalPakket met Rabocard"
  MAPPING[989]="Rabo OnlineKey"
  MAPPING[990]="Rabopas"
  MAPPING[991]="Jongerenpas"
  MAPPING[992]="(Extra) Europas"
  MAPPING[993]="(Extra) Rabocard"
  MAPPING[994]="TopKidpas"
  MAPPING[995]="(Extra) Rabo GoldCard"
  MAPPING[996]="(Extra) Wereldpas"
  MAPPING[997]="(Extra) Rabo BaseCard"

end
