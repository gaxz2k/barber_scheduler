class AddPhotoToProfessionals < ActiveRecord::Migration[8.1]
  def change
    # A foto do profissional é uma coluna `photo` de verdade, e não uma tabela
    # nova com variantes: o fluxo público mostra uma única imagem por pessoa,
    # em um cartão, do tamanho de uma miniatura. Uma tabela `professional_photos`
    # com Active Storage traria `has_many` e um formulário de galeria para um
    # caso que tem uma imagem só.
    #
    # O arquivo fica na coluna e o valor é o `signed_id` do blob do Active
    # Storage — o mesmo caminho de `Barbershop#logo`. Assim o upload, a
    # validação de tipo e a variant de redimensionamento continuam sendo os do
    # Active Storage, em vez de uma segunda implementação de upload no projeto.
    add_column :professionals, :photo, :string
  end
end
