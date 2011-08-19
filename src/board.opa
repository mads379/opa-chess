// 
//  chess.opa
//  chess
//  
//  Created by Mads Hartmann Jensen on 2011-07-31.
//  Copyright 2011 Sideways Coding. All rights reserved.
// 

package chess

import stdlib.web.template
import stdlib.core.map
import stdlib.core

/*
    {Board module}
*/

/*
    Tror sgu det er en god idé hvis vi ændre det således at vi ..
    
    board også har information omkring current_color. Move funktionen skal derfor 
    også ændre farven. Så bliver board objektet sendt frem og tilbage så er der ikke
    nogen grund til "board" state på serveren. 
    
    ændre update så den også tilføjer click events således at det rigtige board bliver opdateret
    
*/

type board = {
    chess_positions: stringmap(intmap(chess_position))
    current_color: colorC
}

Board = {{
    
    /*
        Information that's specific to each game. 
    */
    user_color()    = Option.get(Game.get_state()).color
    channel()       = Option.get(Game.get_state()).channel
    
    
    prepare(board: board): void = 
        do Dom.select_raw("tr") |> domToList(_) |> List.rev(_) |> List.iteri(rowi,tr -> 
            Dom.select_children(tr) |> domToList(_) |> List.iteri(columi, td -> 
                do colorize(rowi+1,columi+1,td,board)
                do labelize(rowi+1,columi+1,td,board)
                do add_on_click_events(rowi+1,columi+1,td,board)
                void
            ,_)
        ,_)
        do place_pieces(board)
        void        

    place_pieces(board: board) = 
        do Dom.select_raw("td img") |> Dom.remove(_)
        do Map.To.val_list(board.chess_positions) |> List.iter(column ->  
            Map.To.val_list(column) |> List.iter(pos -> 
                Option.iter( piece -> 
                    img = Dom.of_xhtml(<img src="/resources/{kind_to_string(piece.kind)}_{colorc_to_string(piece.color)}.png" />)
                    do Position.select_chess_position(pos) |> Dom.put_inside(_,img)
                    void
                ,pos.piece)
            ,_)
        ,_)
        void

    update(board: board) =  
        place_pieces(board)
        

    piece_at(row,column,board): option(chess_position) =
        column_letter = Column.from_int(column+64)
        Map.get(column_letter, board.chess_positions) |> Option.get(_) |> Map.get(row, _) |> Option.get(_) |> pos ->
            match pos with 
                | { piece = { some = {color = color kind = kind}} ...} -> if color == user_color() then { some = pos } else {none}
                | _ -> {none}
        
    add_on_click_events(row,column,td,board: board): void = 
        do Dom.bind(td, {click}, (_ -> 
            
            movable    = piece_at(row,column,board)
            
            if board.current_color == user_color() then 
            (
                if Option.is_some(movable) then 
                (
                    pos = Option.get(movable)
                    do Dom.select_raw("td.movable")  |> Dom.remove_class(_,"movable")
                    do Dom.select_raw("td.selected") |> Dom.remove_class(_,"selected")
                    do Dom.add_class(td, "selected")
                    highlight_possible_movements(pos, Option.get(pos.piece))
                ) else if Dom.has_class(td,"movable") then 
                (
                    posFrom  = Dom.select_raw("td.selected") |> Position.chess_position_from_dom(_, board)
                    posTo    = Position.chess_position_from_dom(td, board)
                    newBoard = move(posFrom, posTo, board) 
                    do Dom.select_raw("td.movable")  |> Dom.remove_class(_,"movable")
                    do Dom.select_raw("td.selected") |> Dom.remove_class(_,"selected")
                    do Network.broadcast({ state = newBoard},channel()) 
                    void
                ) else void
            ) else void 
        ))
        void
    
    highlight_possible_movements(pos: chess_position, piece: piece): void = 
        do Position.movable_chess_positions(pos,piece,user_color()) |> List.iter(pos -> 
            movable = Position.select_chess_position(pos)
            Dom.add_class(movable,"movable")
        ,_)
        void
            
    labelize(row,column,td,board): void = 
        Dom.add_class(td, Column.from_int(column+64) ^ Int.to_string(row)) 
    
    colorize(row,column,td,board): void = 
        if (mod(row,2) == 0) then 
            if mod(column,2) == 0 then Dom.add_class(td, "black") else Dom.add_class(td, "white") 
        else 
            if mod(column,2) == 0 then Dom.add_class(td, "white") else Dom.add_class(td, "black")

    move(posFrom, posTo, board): board = 
        next_color = match board.current_color with 
            | {white} -> {black}
            | {black} -> {white}
        // remove the old piece
        chess_positions = Map.replace(posFrom.letter, rows -> (
            Map.replace(posFrom.number, (oldPos -> { oldPos with piece = {none}}), rows)
        ), board.chess_positions)
        // place the new piece 
        chess_positions2 = Map.replace(posTo.letter, rows -> (
            Map.replace(posTo.number, (oldPos -> { oldPos with piece = posFrom.piece}), rows)
        ), chess_positions)
        { chess_positions = chess_positions2 current_color = next_color}
        
    
    create() = { 
        current_color = {white} 
        chess_positions = (
            columns = ["A","B","C","D","E","F","G","H"] 
            rows = duplicate(8,[8,7,6,5,4,3,2,1])
            List.map( column -> (column, 
                List.map( row -> (row, 
                    pos = { letter = column number = row piece = {none}}
                    match (column, row) with
                        | ("A",8) -> {pos with piece = some({ kind = {rook}   color = {black} })}
                        | ("B",8) -> {pos with piece = some({ kind = {knight} color = {black} })}
                        | ("C",8) -> {pos with piece = some({ kind = {bishop} color = {black} })}
                        | ("D",8) -> {pos with piece = some({ kind = {king}   color = {black} })}
                        | ("E",8) -> {pos with piece = some({ kind = {queen}  color = {black} })}
                        | ("F",8) -> {pos with piece = some({ kind = {bishop} color = {black} })}
                        | ("G",8) -> {pos with piece = some({ kind = {knight} color = {black} })}
                        | ("H",8) -> {pos with piece = some({ kind = {rook}   color = {black} })}
                        | (_,7)   -> {pos with piece = some({ kind = {pawn}   color = {black} })}
                        | (_,2)   -> {pos with piece = some({ kind = {pawn}   color = {white} })}
                        | ("A",1) -> {pos with piece = some({ kind = {rook}   color = {white} })}
                        | ("B",1) -> {pos with piece = some({ kind = {knight} color = {white} })}
                        | ("C",1) -> {pos with piece = some({ kind = {bishop} color = {white} })}
                        | ("D",1) -> {pos with piece = some({ kind = {king}   color = {white} })}
                        | ("E",1) -> {pos with piece = some({ kind = {queen}  color = {white} })}
                        | ("F",1) -> {pos with piece = some({ kind = {bishop} color = {white} })}
                        | ("G",1) -> {pos with piece = some({ kind = {knight} color = {white} })}
                        | ("H",1) -> {pos with piece = some({ kind = {rook}   color = {white} })}
                        | (_,_)   -> pos
                ),rows) |> create_int_map(_)
            ),columns) |> create_string_map(_)
        )
    }
}}