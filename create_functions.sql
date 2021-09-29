--Процедура возврата товара
create or replace procedure return_item(docID int, itemID int)
language plpgsql
as $$
    declare
        retdate date;
        reldate date;
        period int;
        renter int;
        quan int;
        pay int;
    begin
        select distinct release_date from rental_doc
        where rental_docID=docID
        into reldate;

        select distinct rental_period from rental_doc
        where rental_docID=docID
        into period;

        select distinct renterID from rental_doc
        where rental_docID=docID
        into renter;

        select distinct return_date from rental_doc
        where rental_docID=docID
        into retdate;

        if (retdate > (reldate + period * interval '1 day')) then
            insert into pay_doc(pay_docID, renterID) values (default, renter);
            select max(pay_docID) from pay_doc
            where rental_docID=docID
            into pay;
            insert into rent_payment(rental_docID, pay_docID) values (docID, pay);
        end if;


        select distinct quantity from rented_items
        where item_number=itemID and rental_docID=docID
        into quan;

        update item set quantity=quantity+quan
        where item_number=itemID;

        return;
    end
    $$;


--Процедура оплаты аренды
create or replace procedure pay_for_rent_main(rdocs text, pdocID integer, cost integer, inout resultout character varying)
language plpgsql
as $$
    declare
        db_cursor refcursor;
        rdocID record;
        sub decimal;
        allcost decimal;
        amount decimal;
        rID int;
        checkpdoc integer;
        _return varchar;
    begin
        resultout = '';
        open db_cursor for select rentaldocID from rdocs;
            loop
                fetch next from db_cursor into rdocID;
                exit when rdocID is null;

                    select coalesce(sum(r.amount),0) from rent_payment as r
                    where rental_docID=rdocID.rentaldocID
                    into sub;

                    select renterID from rental_doc
                    where rental_docID=rdocID.rentaldocID
                    into rID;

                    select r.pay_docID from pay_doc as p
                    join rent_payment as r on p.pay_docID=r.pay_docID
                    where renterID=rID and rental_docID=rdocID.rentaldocID
                    into checkpdoc;

                    if (pdocID is null) or (checkpdoc is null) then
                        allcost = pay_for_rent(rdocID.rentaldocID);

                        if cost+sub>allcost then
                            amount=allcost;
                            insert into rent_payment values (rdocID.rentaldocID, pdocID, amount);
                            insert into pay_doc(pay_docID, renterID, date) values (default, rID, current_date);
                            _return = 'Оплата аренды '|| rdocID.rentaldocID ||' договора произведена. ';
                        end if;

                        if cost+sub=allcost then
                            amount=allcost;
                            insert into rent_payment values (rdocID.rentaldocID, pdocID, amount);
                            insert into pay_doc(pay_docID, renterID, date) values (default, rID, current_date);
                            _return = 'Оплата аренды '|| rdocID.rentaldocID ||' договора произведена. ';
                        end if;

                        if cost+sub<allcost then
                            amount=cost+sub;
                            insert into rent_payment values (rdocID.rentaldocID, pdocID, amount);
                            insert into pay_doc(pay_docID, renterID, date) values (default, rID, current_date);
                            if amount=0 then
                                _return = 'Невозможно произвести оплату ' || rdocID.rentaldocID ||' договора';
                            end if;
                            _return = 'Для полной оплаты договора '|| rdocID.rentaldocID|| ' необходимо внести еще ' || allcost-sub-cost;
                        end if;

                        cost = cost - amount;
                    end if;

                    if (pdocID is not null) and (checkpdoc is not null) then
                        allcost = pay_for_rent(rdocID.rentaldocID) - sub;

                        if cost+sub>allcost then
                            update rent_payment set amount=allcost+sub where pay_docID=pdocID;
                            _return = 'Оплата аренды '|| rdocID.rentaldocID ||' договора произведена. ';
                        end if;

                        if cost+sub=allcost then
                            update rent_payment set amount=allcost where pay_docID=pdocID;
                            _return = 'Оплата аренды '|| rdocID.rentaldocID ||' договора произведена. ';
                        end if;

                        if cost+sub<allcost then
                            update rent_payment set amount=cost+sub where pay_docID=pdocID;
                            _return = 'Для полной оплаты договора '|| rdocID.rentaldocID|| ' необходимо внести еще ' || allcost-sub-cost;
                        end if;

                        cost = cost - allcost;
                    end if;

                resultout = resultout || E'\n' || _return;
            end loop;

        if cost+allcost>0 then
            resultout = resultout ||  E'\n' || 'Сдача: ' || cost;
        end if;
    end
$$;

create or replace function pay_for_rent(rdocID integer) returns decimal
language plpgsql
as $$
    declare
        pcost decimal;
        pquantity integer;
        i record;
        sum decimal;
    begin
        sum = 0;
        for i in
            select item_number from rented_items
            where rental_docID=rdocID
        loop
                select quantity from rented_items
                where item_number=i.item_number and rental_docID=rdocID
                into pquantity;

                select distinct cost from item
                where item_number=i.item_number
                into pcost;

                sum = sum + pquantity * pcost;
        end loop;

        return sum;
    end
    $$;