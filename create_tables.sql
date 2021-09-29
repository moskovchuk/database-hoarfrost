create table renter
(
	renterID            int generated always as identity not null primary key,
	renter_category     text not null check (renter_category='legal' or renter_category='private'),
	benefit             decimal(3,2) check(benefit>=0.00 and benefit<=100.00)
);

create table legal_person
(
    renterID            int primary key,
    foreign key (renterID)
        references renter,
    name                text,
    address             text,
    telephone_number    integer,
    license_number      integer,
    bank_details        integer,
    "company category"  char
);

create table private_person
(
    renterID            int primary key,
    foreign key (renterID)
        references renter,
    name                text,
    address             text,
    birth_date          date,
    passport_data       int,
    telephone_number    integer
);

create table price_list
(
    price_listID int primary key,
    date date default current_date
);

create table price_list_category
(
    price_list_categoryID int primary key,
    renterID int,
    foreign key (renterID)
        references renter,
    price_listID int,
    foreign key (price_listID)
        references price_list
);

create table rental_doc
(
    rental_docID int generated always as identity primary key,
    renterID int,
    foreign key (renterID)
        references renter,
    price_listID int,
    foreign key (price_listID)
        references price_list,
    create_date date not null default current_date,
    pay_date date,
    release_date date,
    return_date date,
    rental_period int check (rental_period>=1)
);

create table pay_doc
(
    pay_docID int generated always as identity primary key,
    renterID int,
    foreign key (renterID)
        references renter,
    type char check (type='incoming bank order' or type='cash receipt order'),
    date date default current_date
);

create table rent_payment
(
    rental_docID int,
    foreign key (rental_docID)
        references rental_doc,
    pay_docID int,
    foreign key (pay_docID)
        references pay_doc,
    primary key (rental_docID, pay_docID),
    amount decimal check (amount>=0.00)
);

create table item
(
    item_number int primary key,
    name text,
    certificate_number int check (certificate_number>=0),
    packaging char,
    manufacturer_name text,
    cost decimal(6,2) check(cost>=0.00),
    quantity int check ( quantity>=0 )
);

create table item_list_line
(
    price_listID int,
    foreign key (price_listID)
        references price_list,
    item_number int,
    foreign key (item_number)
        references item,
    primary key (price_listID , item_number)
);

create table rented_items
(
    rental_docID int,
    foreign key (rental_docID)
        references rental_doc,
    price_listID int,
    item_number int,
    foreign key (price_listID, item_number)
        references item_list_line,
    primary key (rental_docID, price_listID, item_number),
    quantity int check (quantity>=0)
);

create table rdocs
(
    rentaldocID integer
);
drop table rdocs;