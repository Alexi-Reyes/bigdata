-- Défi 1
with total_commande as (
  select commande_id, sum(quantite * prix_unitaire) as total
  from ligne_commande
  group by commande_id
)
select
  c.livraison_pays as pays,
  d.code as devise,
  count(c.id) as nb_commandes,
  round(sum(tc.total), 2) as chiffre_affaires,
  round(avg(tc.total), 2) as montant_moyen
from commande c
join devise d on d.id = c.devise_id
join total_commande tc on tc.commande_id = c.id
where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
group by c.livraison_pays, d.code
order by chiffre_affaires desc;


-- Défi 2
with total_commande as (
  select commande_id, sum(quantite * prix_unitaire) as total
  from ligne_commande
  group by commande_id
)
select
  c.livraison_ville as ville,
  c.livraison_pays as pays,
  d.code as devise,
  count(c.id) as nb_commandes,
  round(avg(tc.total), 2) as panier_moyen
from commande c
join devise d on d.id = c.devise_id
join total_commande tc on tc.commande_id = c.id
where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
group by c.livraison_ville, c.livraison_pays, d.code
having count(c.id) >= 30
order by panier_moyen desc
limit 20;


-- Défi 3
with total_commande as (
  select commande_id, sum(quantite * prix_unitaire) as total
  from ligne_commande
  group by commande_id
)
select
  cl.id as compte_id,
  cl.prenom,
  cl.nom,
  d.code as devise,
  count(c.id) as nb_commandes_payees,
  round(sum(tc.total), 2) as depense_totale
from commande c
join compte cl on cl.id = c.compte_id
join devise d on d.id = c.devise_id
join total_commande tc on tc.commande_id = c.id
where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
  and c.date_commande >= now() - interval '12 months'
group by cl.id, cl.prenom, cl.nom, d.code
order by nb_commandes_payees desc, depense_totale desc
limit 50;


-- Défi 4
select
  v.id as variante_id,
  v.reference as reference_variante,
  p.nom as produit,
  m.nom as marque,
  v.taille,
  v.couleur,
  v.stock
from variante v
join produit p on p.id = v.produit_id
join marque m on m.id = p.marque_id
where p.est_actif
  and v.id not in (
    select l.variante_id
    from ligne_commande l
    join commande c on c.id = l.commande_id
    where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
  )
order by p.nom, v.reference;


-- Défi 5
select
  m.nom as marque,
  d.code as devise,
  sum(l.quantite) as quantites_vendues,
  round(sum(l.quantite * l.prix_unitaire), 2) as chiffre_affaires
from ligne_commande l
join commande c on c.id = l.commande_id
join devise d on d.id = c.devise_id
join variante v on v.id = l.variante_id
join produit p on p.id = v.produit_id
join marque m on m.id = p.marque_id
where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
group by m.id, m.nom, d.code
order by chiffre_affaires desc;


-- Défi 6
select
  cl.id as compte_id,
  cl.nom,
  cl.prenom,
  cl.email,
  max(c.date_commande) as date_derniere_commande,
  (current_date - max(c.date_commande)::date) as jours_inactivite
from compte cl
join commande c on c.compte_id = cl.id
where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
group by cl.id, cl.nom, cl.prenom, cl.email
having max(c.date_commande) < now() - interval '180 days'
order by date_derniere_commande asc;


-- Défi 8
select distinct on (c.livraison_pays)
  c.livraison_pays as pays,
  cat.nom as categorie,
  sum(l.quantite) as quantites_vendues,
  round(sum(l.quantite * l.prix_unitaire), 2) as chiffre_affaires
from ligne_commande l
join commande c on c.id = l.commande_id
join variante v on v.id = l.variante_id
join produit p on p.id = v.produit_id
join produit_categorie pc on pc.produit_id = p.id
join categorie cat on cat.id = pc.categorie_id
where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
group by c.livraison_pays, cat.id, cat.nom
order by c.livraison_pays, quantites_vendues desc;


-- Défi 18
with bornes as (
  select
    date_trunc('month', min(c.date_commande)) as mois_min,
    date_trunc('month', max(c.date_commande)) as mois_max
  from commande c
  where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
    and c.devise_id = 1
),
calendrier as (
  select generate_series(mois_min, mois_max, interval '1 month') as mois
  from bornes
),
pays as (
  select distinct c.livraison_pays as pays
  from commande c
  where c.devise_id = 1
),
ca_mensuel as (
  select
    c.livraison_pays as pays,
    date_trunc('month', c.date_commande) as mois,
    sum(l.quantite * l.prix_unitaire) as ca
  from ligne_commande l
  join commande c on c.id = l.commande_id
  where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
    and c.devise_id = 1
  group by c.livraison_pays, date_trunc('month', c.date_commande)
),
grille as (
  select
    p.pays as pays,
    to_char(cal.mois, 'YYYY-MM') as mois,
    coalesce(cm.ca, 0) as ca,
    lag(coalesce(cm.ca, 0)) over (
      partition by p.pays order by cal.mois
    ) as ca_precedent
  from pays p
  cross join calendrier cal
  left join ca_mensuel cm on cm.pays = p.pays and cm.mois = cal.mois
)
select
  pays,
  mois,
  round(ca, 2) as ca,
  round(ca_precedent, 2) as ca_precedent,
  round(ca - ca_precedent, 2) as variation_euros,
  round(100.0 * (ca - ca_precedent) / nullif(ca_precedent, 0), 2) as variation_pourcent
from grille
order by pays, mois;


-- Défi 19
with premier_achat as (
  select
    compte_id,
    min(date_commande) as date_premier_achat
  from commande
  where etat in ('payee', 'en_preparation', 'expediee', 'livree')
    and compte_id is not null
  group by compte_id
),
recommandes as (
  select
    p.compte_id,
    bool_or(c.date_commande > p.date_premier_achat and c.date_commande <= p.date_premier_achat + interval '30 days') as reachat_30j,
    bool_or(c.date_commande > p.date_premier_achat and c.date_commande <= p.date_premier_achat + interval '60 days') as reachat_60j,
    bool_or(c.date_commande > p.date_premier_achat and c.date_commande <= p.date_premier_achat + interval '90 days') as reachat_90j
  from premier_achat p
  left join commande c on c.compte_id = p.compte_id
                      and c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
  group by p.compte_id
)
select
  count(*) as nb_clients_acheteurs,
  count(*) filter (where reachat_30j) as nb_reacheteurs_30j,
  round(100.0 * count(*) filter (where reachat_30j) / count(*), 2) as proportion_30j_pct,
  count(*) filter (where reachat_60j) as nb_reacheteurs_60j,
  round(100.0 * count(*) filter (where reachat_60j) / count(*), 2) as proportion_60j_pct,
  count(*) filter (where reachat_90j) as nb_reacheteurs_90j,
  round(100.0 * count(*) filter (where reachat_90j) / count(*), 2) as proportion_90j_pct
from recommandes;


-- Défi 20
select
  l1.variante_id as variante_1_id,
  v1.reference as ref_variante_1,
  p1.nom as produit_1,
  l2.variante_id as variante_2_id,
  v2.reference as ref_variante_2,
  p2.nom as produit_2,
  count(*) as nb_commandes_communes
from ligne_commande l1
join ligne_commande l2 on l2.commande_id = l1.commande_id
                      and l1.variante_id < l2.variante_id
join commande c on c.id = l1.commande_id
join variante v1 on v1.id = l1.variante_id
join produit p1 on p1.id = v1.produit_id
join variante v2 on v2.id = l2.variante_id
join produit p2 on p2.id = v2.produit_id
where c.etat in ('payee', 'en_preparation', 'expediee', 'livree')
group by l1.variante_id, v1.reference, p1.nom, l2.variante_id, v2.reference, p2.nom
order by nb_commandes_communes desc, variante_1_id, variante_2_id
limit 20;
