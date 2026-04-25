--
-- PostgreSQL database dump
--

\restrict deEbdTaFhv9Gcab8B5kcegEdEmazzVsBoheq4Q6cDFIfxINQu6X7Fi6f9lGjhTC

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: BookingStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."BookingStatus" AS ENUM (
    'PENDING',
    'ACCEPTED',
    'REJECTED'
);


ALTER TYPE public."BookingStatus" OWNER TO postgres;

--
-- Name: RideStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."RideStatus" AS ENUM (
    'PLANNED',
    'ONGOING',
    'CANCELLED',
    'COMPLETED'
);


ALTER TYPE public."RideStatus" OWNER TO postgres;

--
-- Name: Role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."Role" AS ENUM (
    'PASSENGER',
    'DRIVER',
    'ADMIN'
);


ALTER TYPE public."Role" OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: BookingRequest; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."BookingRequest" (
    id integer NOT NULL,
    "rideId" integer NOT NULL,
    "passengerId" integer NOT NULL,
    status public."BookingStatus" DEFAULT 'PENDING'::public."BookingStatus" NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."BookingRequest" OWNER TO postgres;

--
-- Name: BookingRequest_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."BookingRequest_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."BookingRequest_id_seq" OWNER TO postgres;

--
-- Name: BookingRequest_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."BookingRequest_id_seq" OWNED BY public."BookingRequest".id;


--
-- Name: Ride; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Ride" (
    id integer NOT NULL,
    "driverId" integer NOT NULL,
    origin text NOT NULL,
    destination text NOT NULL,
    "originLat" double precision,
    "originLng" double precision,
    "destinationLat" double precision,
    "destinationLng" double precision,
    "routeDistanceKm" double precision,
    "routeDurationMin" double precision,
    "departureTime" timestamp(3) without time zone NOT NULL,
    seats integer DEFAULT 4 NOT NULL,
    status public."RideStatus" DEFAULT 'PLANNED'::public."RideStatus" NOT NULL,
    "totalFare" double precision DEFAULT 0 NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."Ride" OWNER TO postgres;

--
-- Name: Ride_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Ride_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Ride_id_seq" OWNER TO postgres;

--
-- Name: Ride_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Ride_id_seq" OWNED BY public."Ride".id;


--
-- Name: SeatBooking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SeatBooking" (
    id integer NOT NULL,
    "rideId" integer NOT NULL,
    "userId" integer NOT NULL,
    "seatNo" integer NOT NULL,
    fare double precision NOT NULL,
    "paymentMethod" text,
    "paymentPhone" text,
    "paidAt" timestamp(3) without time zone,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."SeatBooking" OWNER TO postgres;

--
-- Name: SeatBooking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."SeatBooking_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."SeatBooking_id_seq" OWNER TO postgres;

--
-- Name: SeatBooking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."SeatBooking_id_seq" OWNED BY public."SeatBooking".id;


--
-- Name: User; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."User" (
    id integer NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    password text,
    role public."Role" DEFAULT 'PASSENGER'::public."Role" NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- Name: User_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."User_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."User_id_seq" OWNER TO postgres;

--
-- Name: User_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."User_id_seq" OWNED BY public."User".id;


--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO postgres;

--
-- Name: BookingRequest id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."BookingRequest" ALTER COLUMN id SET DEFAULT nextval('public."BookingRequest_id_seq"'::regclass);


--
-- Name: Ride id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ride" ALTER COLUMN id SET DEFAULT nextval('public."Ride_id_seq"'::regclass);


--
-- Name: SeatBooking id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SeatBooking" ALTER COLUMN id SET DEFAULT nextval('public."SeatBooking_id_seq"'::regclass);


--
-- Name: User id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User" ALTER COLUMN id SET DEFAULT nextval('public."User_id_seq"'::regclass);


--
-- Data for Name: BookingRequest; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."BookingRequest" (id, "rideId", "passengerId", status, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: Ride; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Ride" (id, "driverId", origin, destination, "originLat", "originLng", "destinationLat", "destinationLng", "routeDistanceKm", "routeDurationMin", "departureTime", seats, status, "totalFare", "createdAt", "updatedAt") FROM stdin;
1	1	ইবিএল ব্যাংক, Dhaka, Bangladesh	Lane 1, Dhaka, Bangladesh	23.85916303748241	90.40150779656	23.78498255961589	90.39850321156635	13.4844	14.98333333333333	2026-04-20 22:19:00	4	PLANNED	83	2026-04-20 22:19:20.979	2026-04-20 22:21:15.873
\.


--
-- Data for Name: SeatBooking; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SeatBooking" (id, "rideId", "userId", "seatNo", fare, "paymentMethod", "paymentPhone", "paidAt", "createdAt") FROM stdin;
1	1	2	4	83	\N	\N	\N	2026-04-20 22:20:18.391
2	1	3	2	83	cash	\N	2026-04-20 22:20:52.618	2026-04-20 22:20:48.993
3	1	3	3	83	cash	\N	2026-04-20 22:20:52.618	2026-04-20 22:20:48.993
4	1	3	2	83	cash	\N	2026-04-20 22:21:06.623	2026-04-20 22:21:02.322
5	1	3	3	83	cash	\N	2026-04-20 22:21:06.623	2026-04-20 22:21:02.322
6	1	3	1	83	cash	\N	2026-04-20 22:21:15.871	2026-04-20 22:21:12.58
7	1	3	2	83	cash	\N	2026-04-20 22:21:15.871	2026-04-20 22:21:12.58
8	1	3	3	83	cash	\N	2026-04-20 22:21:15.871	2026-04-20 22:21:12.58
42	1	2	2	103	\N	\N	\N	2026-04-20 19:34:38.5
43	1	2	3	103	\N	\N	\N	2026-04-20 19:34:38.5
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."User" (id, name, email, password, role, "createdAt", "updatedAt") FROM stdin;
1	d1	d1@g.com	$2a$10$egi8Zv7nCCUVTlsg5spJmO9HAohAyatOto5SiIRuTRFMeoYSa8Dze	DRIVER	2026-04-20 22:19:03.644	2026-04-20 22:19:03.644
2	p1	p1@g.com	$2a$10$BIn261sgReSP.sl.j3Yze.6./Zn2jicOwoGxgZg5WJDbpEskO44NK	PASSENGER	2026-04-20 22:19:56.863	2026-04-20 22:19:56.863
3	p2	p2@g.com	$2a$10$kg04xmBIE7QJPPr32rf3zucWds8ybGJxXhHb1qBIt8gl0HyRmV/Z.	PASSENGER	2026-04-20 22:20:38.037	2026-04-20 22:20:38.037
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
a89cffe3-f3b3-4139-ae8a-3b5f0b8bab24	7005b1038a7fc49ea8c573075bfcf7243f4d9b50cf4bb583b3b758cbc1690660	2026-04-17 12:11:06.060426+06	20260414133215_init	\N	\N	2026-04-17 12:11:06.056153+06	1
b4503b61-95b4-46c2-8f7e-ee4216ed183c	eb7b8daec0ee36044749897ffa29c96c41df26fac64762d6285882b2cbf3c99d	2026-04-17 12:11:06.062916+06	20260414142250_add_password_to_user	\N	\N	2026-04-17 12:11:06.060839+06	1
154fd477-cd91-450e-aab6-0ed09d88b39e	7bc857a05a0862100fbce3fb3d7a8e99590075546cb22f4ac145613710d4790a	2026-04-17 12:11:06.064644+06	20260414151354_add_admin_role	\N	\N	2026-04-17 12:11:06.063227+06	1
4f790cb7-7513-4816-917a-77344a3c673e	3b67ec9e35b042efc10c322e219bc3d3f491162541e9cc3daaca1c18fe95ad97	2026-04-17 12:11:06.079032+06	20260416170555_merge_features	\N	\N	2026-04-17 12:11:06.065092+06	1
0166c2d9-2cbc-4b6f-b7ce-515ed6ed3c17	862c16ef3d5d6a38ca0f5603cb33cc783c4d3e1a7d56f620d4443007ba00b15e	2026-04-17 16:09:37.999375+06	20260417100937_seatbooking	\N	\N	2026-04-17 16:09:37.97719+06	1
4ce34f63-ac29-4b1a-ab7b-c04bf3ff8e12	813dfa41573ff8f182e7be045c2c9ad9b774b12f5687b7bba2fb3e8fe577c2a1	2026-04-17 17:31:42.924916+06	20260417113142_seatbooking2	\N	\N	2026-04-17 17:31:42.911182+06	1
9510462e-5480-4ab9-89d9-b658e44bf1a1	54e3ffdb627d03554a203ece1a974142a74015771db529ef470a3b962c85dead	2026-04-19 17:46:53.251499+06	20260419120000_add_fare_totals	\N	\N	2026-04-19 17:46:53.247033+06	1
a3b08aa1-e221-422a-81d6-43984a6d5a90	2bb7ae936407586cc7a54cd58234018a6c2d7cb57fcac8b2b1077bc9149b31e3	2026-04-19 17:47:04.942782+06	20260419114704_payment_2	\N	\N	2026-04-19 17:47:04.932302+06	1
\.


--
-- Name: BookingRequest_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."BookingRequest_id_seq"', 1, false);


--
-- Name: Ride_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Ride_id_seq"', 14, true);


--
-- Name: SeatBooking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."SeatBooking_id_seq"', 43, true);


--
-- Name: User_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."User_id_seq"', 3, true);


--
-- Name: BookingRequest BookingRequest_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."BookingRequest"
    ADD CONSTRAINT "BookingRequest_pkey" PRIMARY KEY (id);


--
-- Name: Ride Ride_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ride"
    ADD CONSTRAINT "Ride_pkey" PRIMARY KEY (id);


--
-- Name: SeatBooking SeatBooking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SeatBooking"
    ADD CONSTRAINT "SeatBooking_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: BookingRequest_rideId_passengerId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "BookingRequest_rideId_passengerId_key" ON public."BookingRequest" USING btree ("rideId", "passengerId");


--
-- Name: User_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "User_email_key" ON public."User" USING btree (email);


--
-- Name: BookingRequest BookingRequest_passengerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."BookingRequest"
    ADD CONSTRAINT "BookingRequest_passengerId_fkey" FOREIGN KEY ("passengerId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: BookingRequest BookingRequest_rideId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."BookingRequest"
    ADD CONSTRAINT "BookingRequest_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES public."Ride"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Ride Ride_driverId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ride"
    ADD CONSTRAINT "Ride_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SeatBooking SeatBooking_rideId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SeatBooking"
    ADD CONSTRAINT "SeatBooking_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES public."Ride"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SeatBooking SeatBooking_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SeatBooking"
    ADD CONSTRAINT "SeatBooking_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict deEbdTaFhv9Gcab8B5kcegEdEmazzVsBoheq4Q6cDFIfxINQu6X7Fi6f9lGjhTC

