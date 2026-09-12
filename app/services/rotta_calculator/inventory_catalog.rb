module RottaCalculator
  # Authoritative furniture/household catalog supplied with the calculator brief.
  # Values are m³ and kg per unit; the server always recomputes totals from this snapshot.
  class InventoryCatalog
    CATALOG_TSV = <<~TSV
      N	Nome	Aliases	montado_m3	desmontado_m3	peso_kg	desmontável
      1	Caixas/Sacos grandes	Caixas/Sacos; Caixa pequena; Caixa média; Caixa grande; Caixas/Sacos pequenas; Caixas/Sacos médias; Caixa de roupas; Caixas com documentos; saco; sacos; sacola; sacolas; bolsa; bolsas; bolsa grande; bolsas grandes	0.1	0.1	12	não
      2	Sofá retrátil com chaise	Sofá com chaise	2.9	2.9	95	não
      3	Sofá 3 lugares	Sofá de 3 lugares	1.5	1.5	55	não
      4	Sofá retrátil 3 lugares	Sofá retrátil de 3 lugares	1.9	1.9	75	não
      5	Sofá 2 metros	Sofá de 2 metros; Sofá 2m; Sofá de 2m	1.1	1.1	52	não
      6	Sofá-cama	Sofá cama; Sofá-cama 2 lugares	1.4	1.4	65	não
      7	Sofá	Sofás	2	2	75	não
      8	Cama box queen	Cama box tamanho queen	2.1	0.3	70	sim
      9	Cama box king	Cama box tamanho king	2.45	0.34	82	sim
      10	Cama box casal	Cama box; Cama box de casal; Cama box com cabeceira	1.9	0.28	62	sim
      11	Cama casal	Cama de casal	1.8	0.15	55	sim
      12	Cama solteiro	Cama de solteiro	1.2	0.155	38	sim
      13	Cama queen	Cama tamanho queen	2.1	0.2	65	sim
      14	Cama king	Cama tamanho king	2.45	0.22	78	sim
      15	Cama	Camas	2.2	0.25	70	sim
      16	Guarda-roupa	Guarda roupa	3.2	0.65	135	sim
      17	Guarda-roupa solteiro 4 portas	Guarda roupa solteiro 4 portas	1.13	0.129	62	sim
      18	Guarda-roupa casal 4 portas	Guarda roupa casal 4 portas	1.86	0.4	88	sim
      19	Guarda-roupa casal 6 portas	Guarda roupa casal 6 portas	2.38	0.67	110	sim
      20	Guarda-roupa casal 8 portas	Guarda roupa casal 8 portas	3.2	0.65	135	sim
      21	Geladeira 1 porta	Geladeira pequena; Geladeira de 1 porta	0.65	0.65	65	não
      22	Geladeira duplex	Geladeira de 2 portas	0.95	0.95	80	não
      23	Geladeira inverse	Geladeira inversa; Geladeira inverse 2 portas	1	1	90	não
      24	Geladeira 4 portas	Geladeira quatro portas	1.3	1.3	110	não
      25	Geladeira grande	Geladeira grande 2 portas	1.3	1.3	95	não
      26	Geladeira side by side	Geladeira side-by-side; Geladeira duas portas lado a lado	1.2	1.2	120	não
      27	Geladeira	Geladeiras	1.3	1.3	95	não
      28	Máquina de lavar	Máquina de lavar roupa; Lavadora de roupas	0.45	0.45	70	não
      29	Mesa de jantar 6 lugares	Mesa jantar 6 lugares	1.08	0.16	45	sim
      30	Mesa de jantar 4 lugares	Mesa jantar 4 lugares	0.78	0.153	34	sim
      31	Mesa de jantar 8 lugares	Mesa jantar 8 lugares	1.65	0.22	62	sim
      32	Cadeira simples		0.24	0.24	8	não
      33	Cadeira com braço	Cadeira com braços	0.3	0.3	10	não
      34	Cadeira de escritório	Cadeira escritório	0.25	0.18	12	sim
      35	Cadeira	Cadeiras	0.24	0.24	8	não
      36	Cadeira gamer	Cadeira gaming	0.35	0.3	20	sim
      37	TV 32 polegadas	TV 32; Televisão 32	0.06	0.06	10	não
      38	TV 43 polegadas	TV 43; Televisão 43	0.09	0.09	13	não
      39	TV 50 polegadas	TV 50; Televisão 50	0.12	0.12	18	não
      40	TV 65 polegadas	TV 65; Televisão 65	0.18	0.18	25	não
      41	TV 75 polegadas	TV 75; Televisão 75	0.25	0.25	32	não
      42	TV	Televisão; Televisor	0.12	0.12	18	não
      43	Aparelho de som médio	Caixa de som média; Caixa de som média JBL; Som médio; JBL média	0.12	0.12	15	não
      44	Aparelho de som	Caixa de som; Som	0.3	0.3	12	não
      45	Aquecedor		0.2	0.2	12	não
      46	Arca tipo baú	Arca baú	0.4	0.4	25	não
      47	Ar-condicionado	Ar condicionado	0.3	0.3	35	não
      48	Armário	Armarios	1.5	0.35	75	sim
      49	Armário 2 portas	Armario 2 portas	1	0.25	55	sim
      50	Armário 3 portas	Armario 3 portas	1.5	0.35	75	sim
      51	Armário de cozinha	Armario cozinha	0.3	0.12	22	sim
      52	Armário paneleiro	Paneleiro	1.1	0.22	55	sim
      53	Armário de lavanderia	Armario lavanderia; Armário médio de lavanderia	0.7	0.25	40	sim
      54	Arquivo de escritório	Arquivo de aço; Arquivo escritório	0.5	0.5	35	não
      55	Aspirador de pó	Aspirador	0.2	0.2	8	não
      56	Balcão		0.5	0.18	35	sim
      57	Banqueta		0.1	0.1	6	não
      58	Bar grande		1	0.35	55	sim
      59	Bar pequeno		0.6	0.25	35	sim
      60	Beliche com colchões	Beliche com colchao; Beliche completo	2.2	0.58	110	sim
      61	Beliche	Beliche sem colchão	2.2	0.28	75	sim
      62	Berço	Berco; Berço sem colchão	0.45	0.16	28	sim
      63	Berço com colchão		0.6	0.18	35	sim
      64	Bicicleta	Bicicleta adulta	0.3	0.3	16	não
      65	Biombo		0.4	0.18	12	sim
      66	Buffet grande		1.2	0.55	70	sim
      67	Buffet pequeno		0.6	0.3	40	sim
      68	Cabideiro		0.3	0.12	12	sim
      69	Carrinho de chá	Carrinho chá	0.1	0.1	8	não
      70	Cesto de roupa	Cesto roupa	0.2	0.2	3	não
      71	Cofre pequeno	Cofre médio; Cofre menor	0.3	0.3	60	não
      72	Cofre	Cofre grande	0.5	0.5	120	não
      73	Colchão casal	Colchão de casal; Colchões casal; Colchões de casal	0.18	0.18	25	não
      74	Colchão solteiro	Colchão de solteiro; Colchões solteiro; Colchões de solteiro	0.12	0.12	16	não
      75	Colchão queen	Colchão tamanho queen; Colchões queen; Colchões tamanho queen	0.21	0.21	28	não
      76	Colchão king	Colchão tamanho king; Colchões king; Colchões tamanho king	0.24	0.24	35	não
      77	Cômoda	Comoda	0.6	0.35	45	sim
      78	Cristaleira		0.8	0.8	55	não
      79	Criado-mudo	Criado mudo; Mesa de cabeceira; Mesa cabeceira	0.2	0.12	15	sim
      80	Mesa de escritório	Mesa escritório; Mesa de computador	0.6	0.15	35	sim
      81	Mesa quadrada pequena	Mesa quadrada; Mesinha quadrada	0.35	0.15	22	sim
      82	Escrivaninha grande	Mesa escritório grande	1	0.1	45	sim
      83	Escrivaninha pequena	Mesa escritório pequena	0.4	0.08	25	sim
      84	Estante de livros alta	Estante alta; Estante de livros grande	0.6	0.16	45	sim
      85	Estante de livros baixa	Estante baixa; Estante de livros pequena	0.3	0.12	28	sim
      86	Fogão 4 bocas	Fogao 4 bocas	0.38	0.38	28	não
      87	Fogão 5 bocas	Fogao 5 bocas	0.52	0.52	38	não
      88	Fogão 6 bocas	Fogao 6 bocas	0.6	0.6	48	não
      89	Fogão	Fogoes	0.6	0.6	48	não
      90	Fogão cooktop	Cooktop	0.08	0.08	12	não
      91	Forno elétrico	Forno eletrico	0.2	0.2	18	não
      92	Forno embutido	Forno de embutir	0.25	0.25	32	não
      93	Freezer horizontal	Freezer horizontal grande	1.1	1.1	65	não
      94	Freezer horizontal pequeno	Freezer pequeno; Freezer 142 litros	0.4	0.4	45	não
      95	Freezer vertical	Freezer em pé	0.6	0.6	60	não
      96	Freezer	Freezers	1.1	1.1	65	não
      97	Impressora	Impressora doméstica; Impressora pequena	0.05	0.05	8	não
      98	Impressora empresarial	Impressora grande; Impressora A3; Multifuncional empresarial	0.3	0.3	35	não
      99	Lava-louças	Lava louças	0.5	0.5	45	não
      100	Máquina de costura portátil	Maquina costura portátil	0.1	0.1	10	não
      101	Mesa de centro	Mesa centro	0.3	0.18	22	sim
      102	Mesa de cozinha	Mesa cozinha	0.3	0.12	20	sim
      103	Micro-ondas	Micro ondas	0.1	0.1	15	não
      104	Piano armário	Piano vertical	1.5	1.5	220	não
      105	Piano de cauda	Piano cauda	3.3	3.3	360	não
      106	Poltrona estofada		0.7	0.7	28	não
      107	Poltrona simples		0.4	0.4	18	não
      108	Rack	Rack simples	0.45	0.15	28	sim
      109	Painel de TV	Painel; Painel de televisão	0.15	0.1	22	sim
      110	Rack com painel	Rack painel	0.9	0.18	48	sim
      111	Secadora		0.35	0.35	42	não
      112	Sofá 2 lugares	Sofá de 2 lugares	1	1	45	não
      113	Sofá 4 lugares	Sofá de 4 lugares	2	2	75	não
      114	Tapete grande		0.3	0.3	18	não
      115	Tapete pequeno		0.1	0.1	6	não
      116	Ventilador		0.1	0.1	5	não
      117	Airfryer	Air fryer; Airfry; Air fry	0.06	0.06	6	não
      118	Liquidificador	Liquidificador de cozinha	0.02	0.02	3	não
      119	Batedeira	Batedeira de bolo	0.04	0.04	5	não
      120	Isopor médio	Isopor; Isopores; Caixa de isopor; Isopor de tamanho médio	0.08	0.08	4	não
      121	Isopor pequeno	Isopor pequeno	0.04	0.04	2	não
      122	Isopor grande	Isopor grande	0.15	0.15	7	não
      123	Computador	Computador desktop; PC	0.15	0.15	12	não
    TSV

    Entry = Struct.new(
      :name,
      :aliases,
      :mounted_m3,
      :disassembled_m3,
      :weight_kg,
      :disassemblable,
      keyword_init: true
    )

    class << self
      def all
        @all ||= CATALOG_TSV.lines.drop(1).filter_map do |line|
          columns = line.chomp.split("\t", -1)
          next if columns.length < 7

          Entry.new(
            name: columns[1].strip,
            aliases: columns[2].to_s.split(';').map(&:strip).reject(&:empty?),
            mounted_m3: Float(columns[3]),
            disassembled_m3: Float(columns[4]),
            weight_kg: Float(columns[5]),
            disassemblable: columns[6].strip.casecmp?('sim')
          )
        rescue ArgumentError
          nil
        end
      end

      def find(value)
        needle = normalize(value)
        return if needle.empty?

        all.find do |entry|
          ([entry.name] + entry.aliases).any? { |candidate| normalize(candidate) == needle }
        end || all.find do |entry|
          ([entry.name] + entry.aliases).any? do |candidate|
            candidate_normalized = normalize(candidate)
            candidate_normalized.include?(needle) || needle.include?(candidate_normalized)
          end
        end
      end

      def normalize(value)
        value.to_s.downcase.unicode_normalize(:nfd)
          .encode('ASCII', invalid: :replace, undef: :replace, replace: '')
          .gsub(/[^a-z0-9]+/, ' ')
          .strip
      end
    end
  end
end

